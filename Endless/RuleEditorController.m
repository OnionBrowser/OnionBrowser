/*
 * Endless
 * Copyright (c) 2014-2017 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "RuleEditorController.h"

@implementation RuleEditorController

UISearchController *searchController;

- (id)initWithStyle:(UITableViewStyle)style
{
	self = [super initWithStyle:style];
	
	self.sortedRuleRows = [[NSMutableArray alloc] init];
	self.inUseRuleRows = [[NSMutableArray alloc] init];

	self.searchResult = [[NSMutableArray alloc] init];
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
	searchController.searchResultsUpdater = self;
	searchController.obscuresBackgroundDuringPresentation = NO;
	self.definesPresentationContext = YES;
	self.navigationItem.searchController = searchController;
	
	self.tableView.delegate = self;
}


#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0)
		return NSLocalizedString(@"Rules in use on current page", nil);
	else
		return NSLocalizedString(@"All rules", nil);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0)
		return [self.inUseRuleRows count];
	else if ([self isFiltering])
		return [self.searchResult count];
	else
		return [self.sortedRuleRows count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rule"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"rule"];
	
	/* TODO: once we have a per-rule view page, enable this */
	//cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	RuleEditorRow *row = [self ruleForTableView:tableView atIndexPath:indexPath];

	cell.textLabel.text = [row textLabel];
	
	NSString *disabled = [self ruleDisabledReason:row];
	if (disabled == nil) {
		if (@available(iOS 13.0, *)) {
			cell.textLabel.textColor = UIColor.labelColor;
			cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
		}
		else {
			cell.textLabel.textColor = UIColor.darkTextColor;
			cell.detailTextLabel.textColor = UIColor.darkGrayColor;
		}

		cell.detailTextLabel.text = [row detailTextLabel];
	}
	else {
		cell.textLabel.textColor = UIColor.systemRedColor;
		if ([row detailTextLabel] == nil || [[row detailTextLabel] isEqualToString:@""])
			cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Disabled: %@", nil), disabled];
		else
			cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%1$@ (Disabled: %2$@)", nil), [row detailTextLabel], disabled];
		cell.detailTextLabel.textColor = UIColor.systemRedColor;
	}
	
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		RuleEditorRow *row = [self ruleForTableView:tableView atIndexPath:indexPath];
		
		if ([self ruleDisabledReason:row] == nil)
			[self disableRuleForRow:row withReason:NSLocalizedString(@"User disabled", nil)];
		else
			[self enableRuleForRow:row];
	}
	
	[tableView reloadData];
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
	RuleEditorRow *row = [self ruleForTableView:tableView atIndexPath:indexPath];

	if ([self ruleDisabledReason:row] == nil)
		return NSLocalizedString(@"Disable", nil);
	else
		return NSLocalizedString(@"Enable", nil);
}


# pragma mark - UISearchResultsUpdating

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
	NSString *search = searchController.searchBar.text;

	[self.searchResult removeAllObjects];

	for (RuleEditorRow *row in self.sortedRuleRows) {
		if ([row textLabel] != nil) {
			NSRange range = [[row textLabel] rangeOfString:search options:NSCaseInsensitiveSearch];

			if (range.length > 0) {
				[self.searchResult addObject:row];
				continue;
			}
		}
		if ([row detailTextLabel] != nil) {
			NSRange range = [[row detailTextLabel] rangeOfString:search options:NSCaseInsensitiveSearch];

			if (range.length > 0) {
				[self.searchResult addObject:row];
				continue;
			}
		}
	}

	[self.tableView reloadData];
}


# pragma mark - Public Methods

- (NSString *)ruleDisabledReason:(RuleEditorRow *)row
{
	return nil;
}

- (void)disableRuleForRow:(RuleEditorRow *)row withReason:(NSString *)reason
{
	abort();
}

- (void)enableRuleForRow:(RuleEditorRow *)row
{
	abort();
}


# pragma mark - Private Methods

- (RuleEditorRow *)ruleForTableView:(UITableView *)tableView atIndexPath:(NSIndexPath *)indexPath
{
	NSMutableArray *group;

	if ([indexPath section] == 0)
		group = [self inUseRuleRows];
	else if ([self isFiltering])
		group = [self searchResult];
	else
		group = [self sortedRuleRows];

	if (group && [group count] > [indexPath row])
		return [group objectAtIndex:indexPath.row];
	else
		return nil;
}

- (BOOL)isFiltering
{
	return searchController.isActive && searchController.searchBar.text.length != 0;
}

@end
