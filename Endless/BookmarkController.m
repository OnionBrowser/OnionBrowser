/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "BookmarkController.h"
#import "OnionBrowser-Swift.h"

@implementation BookmarkController {
	AppDelegate *appDelegate;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	self.title = NSLocalizedString(@"Bookmarks", nil);

	if (appDelegate.webViewController.darkInterface)
		[[self tableView] setBackgroundColor:[UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0]];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[appDelegate.webViewController hideBookmarks];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return Bookmark.all.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return NSLocalizedString(@"Bookmarks", nil);
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
	if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
		UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) view;
		int buttonSize = tableViewHeaderFooterView.frame.size.height - 8;
		
		UIButton *b = [[UIButton alloc] init];
		[b setFrame:CGRectMake(tableViewHeaderFooterView.frame.size.width - buttonSize - 6, 3, buttonSize, buttonSize)];
		[b setBackgroundColor:[UIColor lightGrayColor]];
		[b setTitle:@"X" forState:UIControlStateNormal];
		[[b titleLabel] setFont:[UIFont boldSystemFontOfSize:12]];
		[[b layer] setCornerRadius:buttonSize / 2];
		[b setClipsToBounds:YES];
		
		[b addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
		
		[tableViewHeaderFooterView addSubview:b];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"bookmark"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"bookmark"];

	Bookmark *b = Bookmark.all[indexPath.row];
	if (b != nil) {
		cell.textLabel.text = b.name;
		cell.detailTextLabel.text = b.url.absoluteString;
	}
	
	[cell setShowsReorderControl:YES];
	
	if ([[appDelegate webViewController] darkInterface]) {
		[cell setBackgroundColor:[UIColor clearColor]];
		[[cell textLabel] setTextColor:[UIColor whiteColor]];
		[[cell detailTextLabel] setTextColor:[UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0]];
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	Bookmark *bookmark = Bookmark.all[indexPath.row];
	
	[appDelegate.webViewController prepareForNewURLFromString:bookmark.url.absoluteString];
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)close
{
	[self removeFromParentViewController];
	[[self view] removeFromSuperview];
}

@end
