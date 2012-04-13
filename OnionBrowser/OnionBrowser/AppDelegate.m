//
//  AppDelegate.m
//  OnionBrowser
//
//  Copyright (c) 2012 Mike Tigas. All rights reserved.
//

#import "AppDelegate.h"
#include <Openssl/sha.h>
#import "Reachability.h"

#define TOR_MSG_NONE 0
#define TOR_MSG_AUTHENTICATE 1
#define TOR_MSG_GETSTATUS 2


@implementation AppDelegate

@synthesize window = _window, torThread = _torThread,
            torCheckLoopTimer = _torCheckLoopTimer,
            mSocket = _mSocket,
            lastMessageSent = _lastMessageSent,
            wvc = _wvc,
            webViewStarted = _webViewStarted,
            spoofUserAgent;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    _wvc = [[WebViewController alloc] init];
    [_window addSubview:_wvc.view];
    [_window makeKeyAndVisible];
    
    // listen to changes in connection state
    // (tor has auto detection when external IP changes, but if we went
    //  offline, tor might not handle coming back gracefully -- we will SIGHUP
    //  on those)
    Reachability* reach = [Reachability reachabilityForInternetConnection];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(reachabilityChanged) 
                                                 name:kReachabilityChangedNotification 
                                               object:nil];
    [reach startNotifier];

    
    _webViewStarted = NO;
    spoofUserAgent = NO;
    
    _lastMessageSent = TOR_MSG_NONE;
    _torThread = [[TorWrapper alloc] init];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [_torThread start];
    _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                          target:self
                                                        selector:@selector(activateTorCheckLoop)
                                                        userInfo:nil
                                                         repeats:NO];

    /*******************/
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    
    
    return YES;
}
- (void)reachabilityChanged {
    Reachability* reach = [Reachability reachabilityForInternetConnection];
    if (reach.isReachable) {
        #ifdef DEBUG
            NSLog(@"[tor] Reachability changed (now online), sending HUP" );
        #endif
        [_mSocket writeString:@"SIGNAL HUP\n" encoding:NSUTF8StringEncoding];
        _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.25f
                                                          target:self
                                                        selector:@selector(activateTorCheckLoop)
                                                        userInfo:nil
                                                         repeats:NO];
    }
}


#pragma mark -
#pragma mark Tor control port

- (void)activateTorCheckLoop {
    #ifdef DEBUG
        NSLog(@"[tor] Checking Tor Control Port" );
    #endif
    [ULINetSocket ignoreBrokenPipes];
    // Create a new ULINetSocket connected to the host. Since ULINetSocket is asynchronous, the socket is not
    // connected to the host until the delegate method is called.
    _mSocket = [ULINetSocket netsocketConnectedToHost:@"127.0.0.1" port:60602];
    
    // Schedule the ULINetSocket on the current runloop
    [_mSocket scheduleOnCurrentRunLoop];
    
    // Set the ULINetSocket's delegate to ourself
    [_mSocket setDelegate:self];
}

- (void)disableTorCheckLoop {
    // When in background, don't poll the Tor control port.
    [_mSocket close];
    
    [_torCheckLoopTimer invalidate];
}

- (void)checkTor {
    if (!_webViewStarted) {
        // We haven't loaded a page yet, so we are checking against bootstrap first.
        [_mSocket writeString:@"getinfo status/bootstrap-phase\n" encoding:NSUTF8StringEncoding];
    }
    #ifdef DEBUG
    else {
        // This is a "heartbeat" check, so we are checking our circuits.
        [_mSocket writeString:@"getinfo orconn-status\n" encoding:NSUTF8StringEncoding];
    }
    #endif
}

- (void)netsocketConnected:(ULINetSocket*)inNetSocket {    
    #ifdef DEBUG
        NSLog(@"[tor] Control Port Connected" );
    #endif
    [_mSocket writeString:@"authenticate \"onionbrowsertest\"\n" encoding:NSUTF8StringEncoding];
    _lastMessageSent = TOR_MSG_AUTHENTICATE;
}


- (void)netsocketDisconnected:(ULINetSocket*)inNetSocket {    
    #ifdef DEBUG
        NSLog(@"[tor] Control Port Disconnected" );
    #endif
}

- (void)netsocket:(ULINetSocket*)inNetSocket dataAvailable:(unsigned)inAmount {
    NSString *msgIn = [_mSocket readString:NSUTF8StringEncoding];
    if (_lastMessageSent == TOR_MSG_AUTHENTICATE) {
        if ([msgIn hasPrefix:@"250"]) {
            #ifdef DEBUG
                NSLog(@"[tor] Control Port Authenticated Successfully" );
            #endif
            [_mSocket writeString:@"getinfo status/bootstrap-phase\n" encoding:NSUTF8StringEncoding];
            _lastMessageSent = TOR_MSG_GETSTATUS;
            _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                                  target:self
                                                                selector:@selector(checkTor)
                                                                userInfo:nil
                                                                 repeats:NO];
        }
        #ifdef DEBUG
        else {
            NSLog(@"[tor] Control Port: Got unknown post-authenticate message %@", msgIn);
        }
        #endif
    } else if (_lastMessageSent == TOR_MSG_GETSTATUS) {
        if (!_webViewStarted) {
            if ([msgIn rangeOfString:@"BOOTSTRAP PROGRESS=100"].location != NSNotFound) {
                // This is our first go-around (haven't loaded page into webView yet)
                // but we are now at 100%, so go ahead.
                NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
                resourcePath = [resourcePath stringByReplacingOccurrencesOfString:@"/" withString:@"//"];
                resourcePath = [resourcePath stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
                [_wvc loadURL:[NSURL URLWithString: [NSString stringWithFormat:@"file:/%@//startup.html",resourcePath]]];
                _webViewStarted = YES;
                
                // See "checkTor call in middle of app" a little bit below.
                /*
                #ifdef DEBUG
                _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f
                                                                      target:self
                                                                    selector:@selector(checkTor)
                                                                    userInfo:nil
                                                                     repeats:YES];
                #endif
                */
            } else {
                // Haven't done initial load yet and still waiting on bootstrap, so
                // render status.
                [_wvc renderTorStatus:msgIn];
                _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                                  target:self
                                                                selector:@selector(checkTor)
                                                                userInfo:nil
                                                                 repeats:NO];
            }
        }
        #ifdef DEBUG
        else {
            // This is a response to a "checkTor" call in the middle of our app.
                NSLog(@"[tor] Control Port: orconn-status:\n    %@",
                      [msgIn
                       stringByReplacingOccurrencesOfString:@"\n"
                       withString:@"\n    "]
                     );
        }
        #endif
    }
}

- (void)netsocketDataSent:(ULINetSocket*)inNetSocket { }


- (void)requestNewTorIdentity {
    #ifdef DEBUG
        NSLog(@"[tor] Requesting new identity (SIGNAL NEWNYM)" );
    #endif
    [_mSocket writeString:@"SIGNAL NEWNYM\n" encoding:NSUTF8StringEncoding];
}


#pragma mark -
#pragma mark App lifecycle

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    [self disableTorCheckLoop];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [self disableTorCheckLoop];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    if ((_lastMessageSent != TOR_MSG_NONE) && ![_mSocket isConnected]) {
        #ifdef DEBUG
            NSLog(@"[tor] Came back from background, sending HUP" );
        #endif
        [_mSocket writeString:@"SIGNAL HUP\n" encoding:NSUTF8StringEncoding];
        _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.25f
                                                              target:self
                                                            selector:@selector(activateTorCheckLoop)
                                                            userInfo:nil
                                                             repeats:NO];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [self disableTorCheckLoop];
    _torThread = nil;
}

@end
