/*
 * Endless
 * Copyright (c) 2018 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>

@class Tab;

@interface HistoryController : UITableViewController <UIGestureRecognizerDelegate>

- (HistoryController *)initForTab:(Tab *)tab;

@end

