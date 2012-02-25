//
//  AppDelegate.h
//  OnionBrowser
//
//  Copyright (c) 2012 Mike Tigas. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TorWrapper.h"
#import "ULINetSocket.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (nonatomic, retain) TorWrapper *torThread;

@property (strong, nonatomic) UIWindow *window;

@property (nonatomic, retain) NSTimer *torCheckLoopTimer;
@property (nonatomic, retain) ULINetSocket	*mSocket;

- (void)checkTor;

- (void)activateTorCheckLoop;
- (void)disableTorCheckLoop;

@end
