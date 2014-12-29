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
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
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
	return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
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

@end
