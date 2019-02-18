/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>

@interface SearchResultsController : UITableViewController <UIGestureRecognizerDelegate>

- (void)updateSearchResultsForQuery:(NSString *)query;

@end
