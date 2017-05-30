/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "CookieController.h"

@implementation CookieController {
	AppDelegate *appDelegate;
	NSMutableArray *sortedCookieHosts;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	sortedCookieHosts = [NSMutableArray arrayWithArray:[[appDelegate cookieJar] sortedHostCounts]];

	self.title = NSLocalizedString(@"Cookies and Local Storage", nil);
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil) style:UIBarButtonItemStyleDone target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [sortedCookieHosts count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cookie"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cookie"];
	
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
		[[appDelegate cookieJar] clearAllDataForHost:[[sortedCookieHosts objectAtIndex:[indexPath row]] allKeys][0]];
		[sortedCookieHosts removeObjectAtIndex:[indexPath row]];
		
		[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
	}
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

@end
