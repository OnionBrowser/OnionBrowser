#import "AppDelegate.h"
#import "CookieController.h"

@implementation CookieController

AppDelegate *appDelegate;
NSMutableArray *whitelistHosts;
NSMutableArray *sortedCookieDomains;

enum {
	CookieSectionWhitelist,
	CookieSectionCookies,
	
	CookieSectionCount,
};

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	whitelistHosts = [NSMutableArray arrayWithArray:[[[appDelegate cookieWhitelist] allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]];
	
	NSMutableDictionary *cDomainCount = [[NSMutableDictionary alloc] init];
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\." options:0 error:nil];
	
	for (NSHTTPCookie *c in [[appDelegate cookieStorage] cookies]) {
		/* strip off leading . */
		NSString *cdomain = [regex stringByReplacingMatchesInString:[c domain] options:0 range:NSMakeRange(0, [[c domain] length]) withTemplate:@""];
		
		NSNumber *count = [cDomainCount objectForKey:cdomain];
		if (count == nil)
			count = [NSNumber numberWithInt:0];

		[cDomainCount setObject:[NSNumber numberWithInt:[count intValue] + 1] forKey:cdomain];
	}
	
	sortedCookieDomains = [[NSMutableArray alloc] initWithCapacity:[cDomainCount count]];
	for (NSString *cdomain in [[cDomainCount allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
		[sortedCookieDomains addObject:@{ cdomain : [cDomainCount objectForKey:cdomain] }];
	}

	self.title = @"Cookies";
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addItem:)];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[[appDelegate cookieWhitelist] updateHostsWithArray:whitelistHosts];
	[[appDelegate cookieWhitelist] persist];
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
		return @"All cookies";
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
		return [sortedCookieDomains count];
			
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
		NSDictionary *c = [sortedCookieDomains objectAtIndex:indexPath.row];
		cell.textLabel.text = [c allKeys][0];
		NSNumber *count = [c allValues][0];
		cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ cookie%@", count, (count.intValue == 1 ? @"" : @"s")];
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
			[appDelegate removeCookiesForDomain:[[sortedCookieDomains objectAtIndex:[indexPath row]] allKeys][0]];
			[sortedCookieDomains removeObjectAtIndex:[indexPath row]];
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
