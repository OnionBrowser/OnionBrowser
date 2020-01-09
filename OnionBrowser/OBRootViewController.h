/*
 * Onion Browser
 * Copyright (c) 2012-2018, Tigas Ventures, LLC (Mike Tigas)
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>
#import "OnionManagerDelegate.h"
@class OnionManager;

@interface OBRootViewController : UIViewController <OnionManagerDelegate>

//@property IntroViewController *introVC;
@property UINavigationController *bridgeVC;
//@property ConnectingViewController *conctVC;
//@property ErrorViewController *errorVC;

@property NSUserDefaults *settings;

@property BOOL isStartup;
@property BOOL ignoreTor;
@property float progress;

@end
