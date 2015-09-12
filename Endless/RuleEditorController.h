/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface RuleEditorController : UITableViewController <UISearchBarDelegate, UISearchDisplayDelegate, UITableViewDelegate>

@property AppDelegate *appDelegate;
@property NSMutableArray *sortedRuleNames;
@property NSMutableArray *inUseRuleNames;

@property UISearchBar *searchBar;
@property NSMutableArray *searchResult;

- (NSString *)ruleDisabledReason:(NSString *)rule;
- (void)disableRuleByName:(NSString *)rule withReason:(NSString *)reason;
- (void)enableRuleByName:(NSString *)rule;

@end
