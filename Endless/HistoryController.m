/*
 * Endless
 * Copyright (c) 2018 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "HistoryController.h"
#import "OnionBrowser-Swift.h"

@implementation HistoryController {
	AppDelegate *appDelegate;
	Tab *tab;
	NSArray *history;
}

- (HistoryController *)initForTab:(Tab *)_tab
{
	self = [self init];
	tab = _tab;
	
	NSMutableArray *historyCopy = [tab.history mutableCopy];
	
	/* we don't need the current page */
	[historyCopy removeLastObject];
	
	/* and show in reverse order */
	history = [[historyCopy reverseObjectEnumerator] allObjects];
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil) style:UIBarButtonItemStyleDone target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];

	self.title = NSLocalizedString(@"History", nil);
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0)
		return [history count];
	else
		return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return NSLocalizedString(@"History", nil);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSDictionary *hitem = [history objectAtIndex:[indexPath row]];

	if (hitem == nil)
		return nil;
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"history"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"history"];

	cell.textLabel.text = [hitem objectForKey:@"title"];
	cell.detailTextLabel.text = [hitem objectForKey:@"url"];
	
	[cell setShowsReorderControl:NO];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSDictionary *hitem = [history objectAtIndex:[indexPath row]];
	
	if (hitem != nil)
		[tab load:[NSURL URLWithString:[hitem objectForKey:@"url"]] postParams:nil];
	
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (void)close
{
	[self removeFromParentViewController];
	[[self view] removeFromSuperview];
}

@end

