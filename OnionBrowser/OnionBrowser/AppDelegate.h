//
//  AppDelegate.h
//  OnionBrowser
//
//  Copyright (c) 2012 Mike Tigas. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TorWrapper.h"
#import "ULINetSocket.h"
#import "WebViewController.h"

#define DNT_HEADER_UNSET 0
#define DNT_HEADER_CANTRACK 1
#define DNT_HEADER_NOTRACK 2



@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic) NSUInteger lastMessageSent;

@property (nonatomic) TorWrapper *torThread;

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic) NSTimer *torCheckLoopTimer;
@property (nonatomic) ULINetSocket	*mSocket;

@property (nonatomic) WebViewController *wvc;
@property (nonatomic) Boolean webViewStarted;

@property (nonatomic) Boolean spoofUserAgent;
@property (nonatomic) Byte dntHeader;

@property (nonatomic) NSUInteger torSocksPort;
@property (nonatomic) NSUInteger torControlPort;

- (void)reachabilityChanged;

- (void)activateTorCheckLoop;
- (void)disableTorCheckLoop;
- (void)checkTor;
- (void)requestNewTorIdentity;

@end
