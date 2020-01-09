/*
 * Endless
 * Copyright (c) 2014-2017 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>
#import "RuleEditorRow.h"

@interface RuleEditorController : UITableViewController <UISearchResultsUpdating>

@property NSMutableArray<RuleEditorRow *> *sortedRuleRows;
@property NSMutableArray<RuleEditorRow *> *inUseRuleRows;

@property NSMutableArray<RuleEditorRow *> *searchResult;

- (NSString *)ruleDisabledReason:(RuleEditorRow *)row;
- (void)disableRuleForRow:(RuleEditorRow *)row withReason:(NSString *)reason;
- (void)enableRuleForRow:(RuleEditorRow *)row;

@end
