/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>
#import "OnionManagerDelegate.h"
@import POE;
@class OnionManager;

@interface OBRootViewController : UIViewController <POEDelegate, OnionManagerDelegate>

@property IntroViewController *introVC;
@property ConnectingViewController *conctVC;
@property ErrorViewController *errorVC;

@property OnionManager *onionMgr;

@property NSUserDefaults *settings;

@property BOOL isStartup;
@property BOOL torStarted;
@property float progress;

@end
