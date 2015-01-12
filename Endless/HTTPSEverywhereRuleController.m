#import "AppDelegate.h"
#import "HTTPSEverywhere.h"
#import "HTTPSEverywhereRule.h"
#import "HTTPSEverywhereRuleController.h"

@implementation HTTPSEverywhereRuleController

AppDelegate *appDelegate;
NSMutableArray *sortedRuleNames;
NSMutableArray *inUseRuleNames;

UISearchBar *searchBar;
NSMutableArray *searchResult;
UISearchDisplayController *searchDisplayController;

- (id)initWithStyle:(UITableViewStyle)style
{
	self = [super initWithStyle:style];
	if (self) {
		appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		
		sortedRuleNames = [[NSMutableArray alloc] initWithCapacity:[[HTTPSEverywhere rules] count]];
		
		if ([[appDelegate webViewController] curWebViewTab] != nil) {
			inUseRuleNames = [[NSMutableArray alloc] initWithArray:[[[[[appDelegate webViewController] curWebViewTab] applicableHTTPSEverywhereRules] allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]];
		}
		else {
			inUseRuleNames = [[NSMutableArray alloc] init];
		}
	
		for (NSString *k in [[HTTPSEverywhere rules] allKeys]) {
			if (![inUseRuleNames containsObject:k])
				[sortedRuleNames addObject:k];
		}
		
		sortedRuleNames = [NSMutableArray arrayWithArray:[sortedRuleNames sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]];
		
		searchResult = [NSMutableArray arrayWithCapacity:[sortedRuleNames count]];
	}
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
	
	searchDisplayController = [[UISearchDisplayController alloc] initWithSearchBar:searchBar contentsController:self];
	searchDisplayController.delegate = self;
	searchDisplayController.searchResultsDataSource = self;
	
	[[self tableView] setTableHeaderView:searchBar];

	self.title = @"HTTPS Everywhere Rules";
}

- (void)viewWillDisappear:(BOOL)animated
{
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == 0)
		return @"Rules in use on current page";
	else
		return @"All rules";
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0) {
		return [inUseRuleNames count];
	}
	else {
		if (tableView == searchDisplayController.searchResultsTableView) {
			return [searchResult count];
		}
		else {
			return [sortedRuleNames count];
		}
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rule"];
	
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"rule"];
	}
	
	/* TODO: once we have a per-rule view page, enable this */
	//cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	if ([indexPath section] == 0) {
		cell.textLabel.text = [inUseRuleNames objectAtIndex:indexPath.row];
	}
	else {
		if (tableView == searchDisplayController.searchResultsTableView) {
			cell.textLabel.text = [searchResult objectAtIndex:indexPath.row];
		}
		else {
			cell.textLabel.text = [sortedRuleNames objectAtIndex:indexPath.row];
		}
	}
	
	NSString *disabled = [[HTTPSEverywhere disabledRules] objectForKey:cell.textLabel.text];
	if (disabled != nil) {
		cell.textLabel.textColor = [UIColor redColor];
		cell.detailTextLabel.text = [NSString stringWithFormat:@"Disabled: %@", disabled];
		cell.detailTextLabel.textColor = [UIColor redColor];
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
		NSString *row;
		if (tableView == searchDisplayController.searchResultsTableView) {
			row = [searchResult objectAtIndex:indexPath.row];
		}
		else {
			row = [sortedRuleNames objectAtIndex:indexPath.row];
		}
		
		if ([HTTPSEverywhere ruleNameIsDisabled:row]) {
			[HTTPSEverywhere enableRuleByName:row];
		}
		else {
			[HTTPSEverywhere disableRuleByName:row withReason:@"User disabled"];
		}
	}
	
	[tableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
	[searchResult removeAllObjects];
	
	for (NSString *ruleName in sortedRuleNames) {
		NSRange range = [ruleName rangeOfString:searchString options:NSCaseInsensitiveSearch];
			
		if (range.length > 0) {
			[searchResult addObject:ruleName];
		}
	}
	
	return YES;
}

-(NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
	NSString *row;
	if (tableView == searchDisplayController.searchResultsTableView) {
		row = [searchResult objectAtIndex:indexPath.row];
	}
	else {
		row = [sortedRuleNames objectAtIndex:indexPath.row];
	}

	if ([HTTPSEverywhere ruleNameIsDisabled:row]) {
		return @"Enable";
	}
	else {
		return @"Disable";
	}
}

@end
