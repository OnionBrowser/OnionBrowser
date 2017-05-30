/*
 * Endless
 * Copyright (c) 2017 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "URLBlockerRuleController.h"
#import "URLBlocker.h"

#import "HTTPSEverywhere.h"

@implementation URLBlockerRuleController

- (id)initWithStyle:(UITableViewStyle)style
{
	self = [super initWithStyle:style];
	
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil) style:UIBarButtonItemStyleDone target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];
	
	self.sortedRuleRows = [[NSMutableArray alloc] initWithCapacity:[[URLBlocker targets] count]];
	self.inUseRuleRows = [[NSMutableArray alloc] init];
	
	NSDictionary *inUse = nil;
	if ([[self.appDelegate webViewController] curWebViewTab] != nil)
		inUse = [[[self.appDelegate webViewController] curWebViewTab] applicableURLBlockerTargets];
	
	for (NSString *k in [[[URLBlocker targets] allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) {
		RuleEditorRow *row = [[RuleEditorRow alloc] init];
		row.key = k;
		row.textLabel = k;
		row.detailTextLabel = [[URLBlocker targets] objectForKey:k];
		
		if (inUse && [inUse objectForKey:k])
			[self.inUseRuleRows addObject:row];
		else
			[self.sortedRuleRows addObject:row];
	}
	
	self.inUseRuleRows = [NSMutableArray arrayWithArray:self.inUseRuleRows];
	self.sortedRuleRows = [NSMutableArray arrayWithArray:self.sortedRuleRows];
	
	self.title = NSLocalizedString(@"Blocked 3rd-Party Hosts", nil);
	
	return self;
}

- (NSString *)ruleDisabledReason:(RuleEditorRow *)row
{
	return [[URLBlocker disabledTargets] objectForKey:[row key]];
}

- (void)disableRuleForRow:(RuleEditorRow *)row withReason:(NSString *)reason
{
	[URLBlocker disableTargetByHost:[row key] withReason:reason];
}

- (void)enableRuleForRow:(RuleEditorRow *)row
{
	[URLBlocker enableTargetByHost:[row key]];
}

@end
