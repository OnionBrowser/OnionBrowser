/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "Bookmark.h"
#import "BookmarkController.h"
#import "CookieController.h"
#import "HostSettings.h"
#import "HostSettingsController.h"
#import "IASKAppSettingsViewController.h"
#import "HTTPSEverywhereRuleController.h"
#import "WebViewMenuController.h"

#import "OnePasswordExtension.h"

@implementation WebViewMenuController

AppDelegate *appDelegate;
IASKAppSettingsViewController *appSettingsViewController;
NSMutableArray *buttons;

NSString * const FUNC = @"F";
NSString * const LABEL = @"L";

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	buttons = [[NSMutableArray alloc] initWithCapacity:10];
	
	[buttons addObject:@{ FUNC : @"menuRefresh", LABEL : @"Refresh" }];
	
	/* no point in showing this if the user doesn't have 1p installed */
	if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"onepassword://"]])
		[buttons addObject:@{ FUNC : @"menuOnePassword", LABEL : @"Fill with 1Password" }];

	[buttons addObject:@{ FUNC : @"menuAddOrManageBookmarks", LABEL : @"Add Bookmark" }];
	[buttons addObject:@{ FUNC : @"menuOpenInSafari", LABEL : @"Open in Safari" }];
	[buttons addObject:@{ FUNC : @"menuHTTPSEverywhere", LABEL : @"HTTPS Everywhere" }];
	[buttons addObject:@{ FUNC : @"menuHostSettings", LABEL : @"Host Settings" }];
	[buttons addObject:@{ FUNC : @"menuSettings", LABEL : @"Global Settings" }];
	
	[self.view setBackgroundColor:[UIColor clearColor]];
	[self.tableView setSeparatorInset:UIEdgeInsetsZero];
}

- (CGSize)preferredContentSize
{
	return CGSizeMake(160, [self tableView:self.tableView heightForRowAtIndexPath:[[NSIndexPath alloc] init]] * [buttons count]);
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [buttons count];
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ([cell respondsToSelector:@selector(setSeparatorInset:)])
		[cell setSeparatorInset:UIEdgeInsetsZero];

	if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)])
		[cell setPreservesSuperviewLayoutMargins:NO];

	if ([cell respondsToSelector:@selector(setLayoutMargins:)])
		[cell setLayoutMargins:UIEdgeInsetsZero];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"button"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"button"];
	
	NSDictionary *button = [buttons objectAtIndex:[indexPath row]];
	
	cell.backgroundColor = [UIColor clearColor];
	cell.textLabel.font = [UIFont systemFontOfSize:13];
	cell.textLabel.text = [button objectForKey:LABEL];
	cell.detailTextLabel.text = nil;
	cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
	
	BOOL haveURL = ([[[appDelegate webViewController] curWebViewTab] url] != nil);

	NSString *func = [button objectForKey:FUNC];
	if ([func isEqualToString:@"menuAddOrManageBookmarks"]) {
		if (haveURL && [Bookmark isURLBookmarked:[[[appDelegate webViewController] curWebViewTab] url]]) {
			cell.textLabel.text = @"Manage Bookmarks";
			cell.detailTextLabel.text = @"Page bookmarked";
		}
	}
	else if ([func isEqualToString:@"menuOnePassword"] || [func isEqualToString:@"menuRefresh"] || [func isEqualToString:@"menuOpenInSafari"]) {
		cell.userInteractionEnabled = haveURL;
		cell.textLabel.enabled = haveURL;
	}
	else if ([func isEqualToString:@"menuHTTPSEverywhere"] && haveURL) {
		long ruleCount = [[[[appDelegate webViewController] curWebViewTab] applicableHTTPSEverywhereRules] count];

		if (ruleCount > 0) {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld rule%@ in use", ruleCount, (ruleCount == 1 ? @"" : @"s")];
			cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
		}
	}
	else if ([func isEqualToString:@"menuHostSettings"]) {
		HostSettings *hs = [HostSettings settingsOrDefaultsForHost:[[[[appDelegate webViewController] curWebViewTab] url] host]];
		if (hs && ![hs isDefault]) {
			cell.detailTextLabel.text = @"Custom settings";
			cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
		}
		else {
			cell.detailTextLabel.text = @"Using defaults";
			cell.detailTextLabel.textColor = [UIColor grayColor];
		}
	}

	return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 35;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[[appDelegate webViewController] dismissPopover];
	NSDictionary *button = [buttons objectAtIndex:[indexPath row]];

	SEL action = NSSelectorFromString([button objectForKey:FUNC]);
	
	if ([self respondsToSelector:action])
		[self performSelector:action];
	else
		NSLog(@"can't call %@", NSStringFromSelector(action));
}


/* individual menu item functions */


- (void)menuRefresh
{
	[[appDelegate webViewController] forceRefresh];
}

- (void)menuOnePassword
{
	[[OnePasswordExtension sharedExtension] fillItemIntoWebView:[[[appDelegate webViewController] curWebViewTab] webView] forViewController:[appDelegate webViewController] sender:[[appDelegate webViewController] settingsButton] showOnlyLogins:NO completion:^(BOOL success, NSError *error) {
		if (!success)
			NSLog(@"[OnePasswordExtension] failed to fill into webview: %@", error);
	}];
}

- (void)menuOpenInSafari
{
	WebViewTab *wvt = [[appDelegate webViewController] curWebViewTab];
	if (wvt && [wvt url])
		[[UIApplication sharedApplication] openURL:[wvt url] options:@{} completionHandler:nil];
}

- (void)menuHTTPSEverywhere
{
	HTTPSEverywhereRuleController *herc = [[HTTPSEverywhereRuleController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:herc];
	[[appDelegate webViewController] presentViewController:navController animated:YES completion:nil];
}

- (void)menuHostSettings
{
	HostSettingsController *hsc = [[HostSettingsController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:hsc];
	[[appDelegate webViewController] presentViewController:navController animated:YES completion:nil];
	
	/* if we have custom settings, skip directly to them */
	HostSettings *hs = [HostSettings settingsOrDefaultsForHost:[[[[appDelegate webViewController] curWebViewTab] url] host]];
	if (hs && ![hs isDefault])
		[hsc showDetailsForHost:[hs hostname]];
}

- (void)menuAddOrManageBookmarks
{
	BookmarkController *bc = [[BookmarkController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bc];
	[[appDelegate webViewController] presentViewController:navController animated:YES completion:nil];
}

- (void)menuSettings
{
	if (!appSettingsViewController) {
		appSettingsViewController = [[IASKAppSettingsViewController alloc] init];
		appSettingsViewController.delegate = [appDelegate webViewController];
		appSettingsViewController.showDoneButton = YES;
		appSettingsViewController.showCreditsFooter = NO;
	}
	
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:appSettingsViewController];
	[[appDelegate webViewController] presentViewController:navController animated:YES completion:nil];
}

@end
