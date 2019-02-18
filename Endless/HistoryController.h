/*
 * Endless
 * Copyright (c) 2018 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>

#import "WebViewTab.h"

@interface HistoryController : UITableViewController <UIGestureRecognizerDelegate>

- (HistoryController *)initForTab:(WebViewTab *)tab;

@end

