#import "AppDelegate.h"
#import "CookieController.h"

@implementation CookieController

AppDelegate *appDelegate;
NSMutableArray *whitelistHosts;
NSMutableArray *sortedCookieHosts;

enum {
	CookieSectionWhitelist,
	CookieSectionCookies,
	
	CookieSectionCount,
};

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	whitelistHosts = [NSMutableArray arrayWithArray:[[appDelegate cookieJar] whitelistedHosts]];
	
	sortedCookieHosts = [NSMutableArray arrayWithArray:[[appDelegate cookieJar] sortedHostCounts]];

	self.title = @"Cookies";
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addItem:)];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[[appDelegate cookieJar] updateWhitelistedHostsWithArray:whitelistHosts];
	[[appDelegate cookieJar] persist];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return CookieSectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section) {
	case CookieSectionWhitelist:
		return @"Whitelisted cookie domains";
	case CookieSectionCookies:
		return @"All cookies and local storage";
	default:
		return @"";
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section) {
	case CookieSectionWhitelist:
		return [whitelistHosts count];
			
	case CookieSectionCookies:
		return [sortedCookieHosts count];
			
	default:
		return 0;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cookie"];
	
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cookie"];
	}
	
	switch (indexPath.section) {
	case CookieSectionWhitelist:
		cell.textLabel.text = [whitelistHosts objectAtIndex:indexPath.row];
		break;
	
	case CookieSectionCookies: {
		NSDictionary *c = [sortedCookieHosts objectAtIndex:indexPath.row];
		cell.textLabel.text = [c allKeys][0];
		NSDictionary *ccounts = [c allValues][0];
		int ccount = [[ccounts objectForKey:@"cookies"] intValue];
		int lscount = [[ccounts objectForKey:@"localStorage"] intValue];

		if (ccount) {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%d cookie%@", ccount, (ccount == 1 ? @"" : @"s")];
		}
		if (lscount) {
			if (ccount) {
				cell.detailTextLabel.text = [NSString stringWithFormat:@"%@, local storage", cell.detailTextLabel.text];
			}
			else {
				cell.detailTextLabel.text = [NSString stringWithFormat:@"local storage"];
			}
		}
		}
		break;
	}
	
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		switch (indexPath.section) {
		case CookieSectionWhitelist:
			[whitelistHosts removeObjectAtIndex:[indexPath row]];
			break;
			
		case CookieSectionCookies:
			[[appDelegate cookieJar] clearAllDataForHost:[[sortedCookieHosts objectAtIndex:[indexPath row]] allKeys][0]];
			[sortedCookieHosts removeObjectAtIndex:[indexPath row]];
			break;
		}
		
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (void)addItem:sender
{
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Cookie whitelist" message:@"Enter the full hostname or dot-domain to whitelist" preferredStyle:UIAlertControllerStyleAlert];
	[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = @".example.com";
	}];
	
	UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		UITextField *host = alertController.textFields.firstObject;
		if (host && ![[host text] isEqualToString:@""]) {
			[whitelistHosts addObject:[host text]];
			[self.tableView reloadData];
		}
	}];
	
	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
	[alertController addAction:cancelAction];
	[alertController addAction:okAction];
	
	[self presentViewController:alertController animated:YES completion:nil];
}

@end
