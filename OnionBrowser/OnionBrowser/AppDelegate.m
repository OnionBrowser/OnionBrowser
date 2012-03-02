//
//  AppDelegate.m
//  OnionBrowser
//
//  Copyright (c) 2012 Mike Tigas. All rights reserved.
//

#import "AppDelegate.h"
#include <Openssl/sha.h>

#define TOR_MSG_NONE 0
#define TOR_MSG_AUTHENTICATE 1
#define TOR_MSG_GETSTATUS 2


@implementation AppDelegate

@synthesize window = _window, torThread = _torThread,
            torCheckLoopTimer = _torCheckLoopTimer,
            mSocket = _mSocket,
            lastMessageSent = _lastMessageSent,
            wvc = _wvc,
            webViewStarted = _webViewStarted;


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _webViewStarted = NO;
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    _torThread = [[TorWrapper alloc] init];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [_torThread start];
    
    _lastMessageSent = TOR_MSG_NONE;
    
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    
    _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f
                                                          target:self
                                                        selector:@selector(activateTorCheckLoop)
                                                        userInfo:nil
                                                         repeats:NO];

    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    _window.backgroundColor = [UIColor whiteColor];
    
    _wvc = [[WebViewController alloc] init];
    //[wvc.myWebView setBounds:[[UIScreen mainScreen] bounds]];
    [_window addSubview:_wvc.view];
    
    [_window makeKeyAndVisible];
    
    return YES;
}

- (void)netsocketConnected:(ULINetSocket*)inNetSocket {    
    #ifdef DEBUG
        NSLog(@"[tor] Control Port Connected" );
    #endif
    [_mSocket writeString:@"authenticate \"onionbrowsertest\"\n" encoding:NSUTF8StringEncoding];
    _lastMessageSent = TOR_MSG_AUTHENTICATE;
}

- (void)checkTor {
    // Send a simple HTTP 1.0 header to the server and hopefully we won't be rejected
    //[_mSocket writeString:@"getinfo circuit-status\n\r" encoding:NSUTF8StringEncoding];
    //[_mSocket writeString:@"setevents circ" encoding:NSUTF8StringEncoding];
    //[_mSocket writeString:@"setevents circ status_general\n" encoding:NSUTF8StringEncoding];
    [_mSocket writeString:@"getinfo circuit-status\n" encoding:NSUTF8StringEncoding];
    _lastMessageSent = TOR_MSG_GETSTATUS;
}

- (void)netsocketDisconnected:(ULINetSocket*)inNetSocket {    
    #ifdef DEBUG
        NSLog(@"[tor] Control Port Disconnected" );
    #endif
}

- (void)netsocket:(ULINetSocket*)inNetSocket dataAvailable:(unsigned)inAmount {
    NSString *msgIn = [_mSocket readString:NSUTF8StringEncoding];
    if (_lastMessageSent == TOR_MSG_AUTHENTICATE) {
        if ([msgIn hasPrefix:@"250 OK"]) {
            #ifdef DEBUG
                NSLog(@"[tor] Control Port Authenticated Successfully" );
            #endif
            [_mSocket writeString:@"getinfo circuit-status\n\r" encoding:NSUTF8StringEncoding];
            _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f
                                                                  target:self
                                                                selector:@selector(checkTor)
                                                                userInfo:nil
                                                                 repeats:NO];
        } else {
            NSLog(@"[tor] Control Port: Got unknown post-authenticate message %@", msgIn);
        }
    } else if (_lastMessageSent == TOR_MSG_GETSTATUS) {
        NSUInteger built_connections = 0;
        NSUInteger inprogress_connections = 0;
        NSArray *connections = [msgIn componentsSeparatedByString:@"\n"];
        for (int i=0; i<[connections count]; i++) {
            NSString *line = [connections objectAtIndex:i];
            NSArray *line_bits = [line componentsSeparatedByString:@" "];
            if (([line_bits count] > 2) && ([@"BUILT" isEqualToString:[line_bits objectAtIndex:1]])) {
                built_connections += 1;
            }
            if (([line_bits count] > 2) && ([@"EXTENDED" isEqualToString:[line_bits objectAtIndex:1]])) {
                inprogress_connections += 1;
            }
        }
//        if ((inprogress_connections+built_connections > 1) && !_webViewStarted) {
        if ((built_connections > 0) && !_webViewStarted) {
            NSURL *navigationUrl = [NSURL URLWithString:@"https://check.torproject.org/"];
            [_wvc loadURL:navigationUrl];
            _webViewStarted = YES;
        }
        _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.1f
                                                              target:self
                                                            selector:@selector(checkTor)
                                                            userInfo:nil
                                                             repeats:NO];
    }
}

- (void)netsocketDataSent:(ULINetSocket*)inNetSocket { }

#pragma mark -

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
    [_mSocket close];

    [_torCheckLoopTimer invalidate];
}

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
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    if ((_lastMessageSent != TOR_MSG_NONE) && ![_mSocket isConnected]) {
        //[self activateTorCheckLoop];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    [self disableTorCheckLoop];
    [_torThread halt_tor];
}

@end
