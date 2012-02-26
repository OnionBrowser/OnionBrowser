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

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic) NSUInteger lastMessageSent;

@property (nonatomic, retain) TorWrapper *torThread;

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, retain) NSTimer *torCheckLoopTimer;
@property (nonatomic, retain) ULINetSocket	*mSocket;


@property (nonatomic, retain) WebViewController *wvc;
@property (nonatomic) Boolean webViewStarted;


- (void)checkTor;

- (void)activateTorCheckLoop;
- (void)disableTorCheckLoop;

@end
