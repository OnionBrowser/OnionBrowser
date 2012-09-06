//
//  TorController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 9/5/12.
//
//

#import "TorController.h"
#import "NSData+Conversion.h"
#import "AppDelegate.h"
#import "Reachability.h"

@implementation TorController

#define STATUS_CHECK_TIMEOUT 1.0f

@synthesize
    didFirstConnect,
    torControlPort = _torControlPort,
    torSocksPort = _torSocksPort,
    torThread = _torThread,
    torCheckLoopTimer = _torCheckLoopTimer,
    torStatusTimeoutTimer = _torStatusTimeoutTimer,
    mSocket = _mSocket,
    controllerIsAuthenticated = _controllerIsAuthenticated
;

-(id)init {
    if (self=[super init]) {
        _torControlPort = (arc4random() % (57343-49153)) + 49153;
        _torSocksPort = (arc4random() % (65534-57344)) + 57344;
        
        _controllerIsAuthenticated = NO;
        
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
    }
    return self;
}

-(void)startTor {
    // Starts or restarts tor thread.
    
    if (_torCheckLoopTimer != nil) {
        [_torCheckLoopTimer invalidate];
    }
    if (_torStatusTimeoutTimer != nil) {
        [_torStatusTimeoutTimer invalidate];
    }
    if (_torThread != nil) {
        [_torThread cancel];
        _torThread = nil;
    }
    
    _torThread = [[TorWrapper alloc] init];
    [_torThread start];
    
    _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                          target:self
                                                        selector:@selector(activateTorCheckLoop)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)hupTor {
    if (_torCheckLoopTimer != nil) {
        [_torCheckLoopTimer invalidate];
    }

    [_mSocket writeString:@"SIGNAL HUP\n" encoding:NSUTF8StringEncoding];
    _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.25f
                                                          target:self
                                                        selector:@selector(activateTorCheckLoop)
                                                        userInfo:nil
                                                         repeats:NO];
}

- (void)requestNewTorIdentity {
    #ifdef DEBUG
    NSLog(@"[tor] Requesting new identity (SIGNAL NEWNYM)" );
    #endif
    [_mSocket writeString:@"SIGNAL NEWNYM\n" encoding:NSUTF8StringEncoding];
}


#pragma mark -
#pragma mark App / connection status callbacks

- (void)reachabilityChanged {
    Reachability* reach = [Reachability reachabilityForInternetConnection];
    if (reach.isReachable) {
        #ifdef DEBUG
        NSLog(@"[tor] Reachability changed (now online), sending HUP" );
        #endif
        [self hupTor];
    }
}


- (void)appDidEnterBackground {
    [self disableTorCheckLoop];
}

- (void)appDidBecomeActive {
    if (![_mSocket isConnected]) {
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

#pragma mark -
#pragma mark Tor control port

- (void)activateTorCheckLoop {
    #ifdef DEBUG
    NSLog(@"[tor] Checking Tor Control Port" );
    #endif

    _controllerIsAuthenticated = NO;
    
    [ULINetSocket ignoreBrokenPipes];
    // Create a new ULINetSocket connected to the host. Since ULINetSocket is asynchronous, the socket is not
    // connected to the host until the delegate method is called.
    _mSocket = [ULINetSocket netsocketConnectedToHost:@"127.0.0.1" port:_torControlPort];
    
    // Schedule the ULINetSocket on the current runloop
    [_mSocket scheduleOnCurrentRunLoop];
    
    // Set the ULINetSocket's delegate to ourself
    [_mSocket setDelegate:self];
}

- (void)disableTorCheckLoop {
    // When in background, don't poll the Tor control port.
    [ULINetSocket ignoreBrokenPipes];
    [_mSocket close];
    _mSocket = nil;
    
    [_torCheckLoopTimer invalidate];
}

- (void)checkTor {
    if (!didFirstConnect) {
        // We haven't loaded a page yet, so we are checking against bootstrap first.
        [_mSocket writeString:@"getinfo status/bootstrap-phase\n" encoding:NSUTF8StringEncoding];
    }
    else {
        // This is a "heartbeat" check, so we are checking our circuits.
        [_mSocket writeString:@"getinfo orconn-status\n" encoding:NSUTF8StringEncoding];
        if (_torStatusTimeoutTimer != nil) {
            [_torStatusTimeoutTimer invalidate];
        }
        _torStatusTimeoutTimer = [NSTimer scheduledTimerWithTimeInterval:STATUS_CHECK_TIMEOUT
                                                              target:self
                                                            selector:@selector(checkTorStatusTimeout)
                                                            userInfo:nil
                                                             repeats:NO];
    }
}

- (void)checkTorStatusTimeout {
    // Our orconn-status check didn't return before the alotted timeout.
    // (We're basically giving it STATUS_CHECK_TIMEOUT seconds -- default 1 sec
    // -- since this is a LOCAL port and LOCAL instance of tor, it should be
    // near instantaneous.)
    //
    // Fail: Restart Tor? (Maybe HUP?)
    NSLog(@"[tor] checkTor timed out, attempting to restart tor");
    [self startTor];
}



- (void)netsocketConnected:(ULINetSocket*)inNetSocket {
    /* Authenticate on first control port connect */
    #ifdef DEBUG
    NSLog(@"[tor] Control Port Connected" );
    #endif
    NSData *torCookie = [_torThread readTorCookie];
    
    NSString *authMsg = [NSString stringWithFormat:@"authenticate %@\n",
                         [torCookie hexadecimalString]];
    [_mSocket writeString:authMsg encoding:NSUTF8StringEncoding];
    
    _controllerIsAuthenticated = NO;
}


- (void)netsocketDisconnected:(ULINetSocket*)inNetSocket {
    #ifdef DEBUG
    NSLog(@"[tor] Control Port Disconnected" );
    #endif
    
    // Attempt to reconnect the netsocket
    [self disableTorCheckLoop];
    [self activateTorCheckLoop];
}

- (void)netsocket:(ULINetSocket*)inNetSocket dataAvailable:(unsigned)inAmount {
    NSString *msgIn = [_mSocket readString:NSUTF8StringEncoding];
    
    if (!_controllerIsAuthenticated) {
        // Response to AUTHENTICATE
        if ([msgIn hasPrefix:@"250"]) {
            #ifdef DEBUG
            NSLog(@"[tor] Control Port Authenticated Successfully" );
            #endif
            _controllerIsAuthenticated = YES;

            [_mSocket writeString:@"getinfo status/bootstrap-phase\n" encoding:NSUTF8StringEncoding];
            _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                                  target:self
                                                                selector:@selector(checkTor)
                                                                userInfo:nil
                                                                 repeats:NO];
        }
        else {
            #ifdef DEBUG
            NSLog(@"[tor] Control Port: Got unknown post-authenticate message %@", msgIn);
            #endif
            // Could not authenticate with control port. This is the worst thing
            // that can happen on app init and should fail badly so that the
            // app does not just hang there. So: crash. :(
            exit(0);
        }
    } else if ([msgIn rangeOfString:@"-status/bootstrap-phase="].location != NSNotFound) {
        // Response to "getinfo status/bootstrap-phase"
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        WebViewController *wvc = appDelegate.appWebView;
        if (!didFirstConnect) {
            if ([msgIn rangeOfString:@"BOOTSTRAP PROGRESS=100"].location != NSNotFound) {
                // This is our first go-around (haven't loaded page into webView yet)
                // but we are now at 100%, so go ahead.
                NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
                resourcePath = [resourcePath stringByReplacingOccurrencesOfString:@"/" withString:@"//"];
                resourcePath = [resourcePath stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
                [wvc loadURL:[NSURL URLWithString: [NSString stringWithFormat:@"file:/%@//startup.html",resourcePath]]];
                didFirstConnect = YES;
                
                // See "checkTor call in middle of app" a little bit below.
                 _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f
                 target:self
                 selector:@selector(checkTor)
                 userInfo:nil
                 repeats:NO];
            } else {
                // Haven't done initial load yet and still waiting on bootstrap, so
                // render status.
                [wvc renderTorStatus:msgIn];
                _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:0.15f
                                                                      target:self
                                                                    selector:@selector(checkTor)
                                                                    userInfo:nil
                                                                     repeats:NO];
            }
        }
    } else if ([msgIn rangeOfString:@"+orconn-status="].location != NSNotFound) {
        [_torStatusTimeoutTimer invalidate];
        
        // Response to "getinfo orconn-status"
        // This is a response to a "checkTor" call in the middle of our app.
        if ([msgIn rangeOfString:@"250 OK"].location == NSNotFound) {
            // Bad stuff! Should HUP since this means we can still talk to
            // Tor, but Tor is having issues with it's onion routing connections.
            NSLog(@"[tor] Control Port: orconn-status: NOT OK\n    %@",
                  [msgIn
                   stringByReplacingOccurrencesOfString:@"\n"
                   withString:@"\n    "]
                  );
            
            [self hupTor];
        } else {
            #ifdef DEBUG
            NSLog(@"[tor] Control Port: orconn-status: OK");
            #endif
            _torCheckLoopTimer = [NSTimer scheduledTimerWithTimeInterval:5.0f
                                                                  target:self
                                                                selector:@selector(checkTor)
                                                                userInfo:nil
                                                                 repeats:NO];
        }
    }
}

- (void)netsocketDataSent:(ULINetSocket*)inNetSocket { }


@end
