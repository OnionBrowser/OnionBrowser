/*
 * Endless
 * Copyright (c) 2014-2017 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "HTTPSEverywhereRuleController.h"
#import "HTTPSEverywhere.h"
#import "HTTPSEverywhereRule.h"

@implementation HTTPSEverywhereRuleController

- (id)initWithStyle:(UITableViewStyle)style
{
	self = [super initWithStyle:style];
	
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil) style:UIBarButtonItemStyleDone target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];

	self.sortedRuleRows = [[NSMutableArray alloc] initWithCapacity:[[HTTPSEverywhere rules] count]];
	self.inUseRuleRows = [[NSMutableArray alloc] init];
	
	NSDictionary *inUse = nil;
	if ([[self.appDelegate webViewController] curWebViewTab] != nil)
		inUse = [[[self.appDelegate webViewController] curWebViewTab] applicableHTTPSEverywhereRules];

	for (NSString *k in [[[HTTPSEverywhere rules] allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
		RuleEditorRow *row = [[RuleEditorRow alloc] init];
		row.key = k;
		row.textLabel = k;
		
		if (inUse && [inUse objectForKey:k])
			[self.inUseRuleRows addObject:row];
		else
			[self.sortedRuleRows addObject:row];
	}

	self.inUseRuleRows = [NSMutableArray arrayWithArray:self.inUseRuleRows];
	self.sortedRuleRows = [NSMutableArray arrayWithArray:self.sortedRuleRows];
	
	self.title = NSLocalizedString(@"HTTPS Everywhere Rules", nil);
	
	return self;
}

- (NSString *)ruleDisabledReason:(RuleEditorRow *)row
{
	return [[HTTPSEverywhere disabledRules] objectForKey:[row key]];
}

- (void)disableRuleForRow:(RuleEditorRow *)row withReason:(NSString *)reason
{
	[HTTPSEverywhere disableRuleByName:[row key] withReason:reason];
}

- (void)enableRuleForRow:(RuleEditorRow *)row
{
	[HTTPSEverywhere enableRuleByName:[row key]];
}

@end
