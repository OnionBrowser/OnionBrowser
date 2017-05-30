/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "Bookmark.h"
#import "CookieController.h"
#import "HostSettings.h"
#import "HostSettingsController.h"
#import "IASKAppSettingsViewController.h"
#import "HTTPSEverywhereRuleController.h"
#import "URLBlockerRuleController.h"
#import "WebViewMenuController.h"
#import "BridgeViewController.h"

#import "OnePasswordExtension.h"
#import "TUSafariActivity.h"

#ifdef SHOW_DONATION_CONTROLLER
#include "DonationViewController.h"
#endif

@implementation WebViewMenuController {
	AppDelegate *appDelegate;
	IASKAppSettingsViewController *appSettingsViewController;
	NSMutableArray *buttons;
}

NSString * const FUNC = @"F";
NSString * const LABEL = @"L";

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	buttons = [[NSMutableArray alloc] initWithCapacity:10];
	
    [buttons addObject:@{ FUNC : @"menuRefresh", LABEL : NSLocalizedString(@"Refresh", nil) }];

    /* no point in showing this if the user doesn't have 1p installed */
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"onepassword://"]])
    [buttons addObject:@{ FUNC : @"menuOnePassword", LABEL : NSLocalizedString(@"Fill with 1Password", nil) }];

    [buttons addObject:@{ FUNC : @"menuAddOrManageBookmarks", LABEL : NSLocalizedString(@"Manage Bookmarks", nil) }];
    [buttons addObject:@{ FUNC : @"menuShare", LABEL : NSLocalizedString(@"Share URL", nil) }];
    [buttons addObject:@{ FUNC : @"menuURLBlocker", LABEL : NSLocalizedString(@"URL Blocker", nil) }];
    [buttons addObject:@{ FUNC : @"menuHTTPSEverywhere", LABEL : NSLocalizedString(@"HTTPS Everywhere", nil) }];
    [buttons addObject:@{ FUNC : @"menuHostSettings", LABEL : NSLocalizedString(@"Host Settings", nil) }];
    [buttons addObject:@{ FUNC : @"menuSettings", LABEL : NSLocalizedString(@"Global Settings", nil) }];
    [buttons addObject:@{ FUNC : @"bridgeSettings", LABEL : NSLocalizedString(@"Tor Connection Settings", nil) }];

	[self.view setBackgroundColor:[UIColor clearColor]];
	[self.tableView setSeparatorInset:UIEdgeInsetsZero];
	
	if ([[appDelegate webViewController] darkInterface])
		[self.tableView setSeparatorColor:[UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:0.75]];
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
	
	if ([[appDelegate webViewController] darkInterface]) {
		cell.textLabel.textColor = [UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0];
		cell.detailTextLabel.textColor = [UIColor grayColor];
	}
	
	BOOL haveURL = ([[[appDelegate webViewController] curWebViewTab] url] != nil);

	NSString *func = [button objectForKey:FUNC];
	if ([func isEqualToString:@"menuAddOrManageBookmarks"]) {
		if (haveURL && [Bookmark isURLBookmarked:[[[appDelegate webViewController] curWebViewTab] url]]) {
            cell.textLabel.text = NSLocalizedString(@"Bookmarks", nil);
            cell.detailTextLabel.text = NSLocalizedString(@"Page bookmarked", nil);
		}
	}
	else if ([func isEqualToString:@"menuOnePassword"] || [func isEqualToString:@"menuRefresh"] || [func isEqualToString:@"menuShare"]) {
		cell.userInteractionEnabled = haveURL;
		cell.textLabel.enabled = haveURL;
	}
	else if ([func isEqualToString:@"menuURLBlocker"] && haveURL) {
		long ruleCount = [[[[appDelegate webViewController] curWebViewTab] applicableURLBlockerTargets] count];
		
		if (ruleCount > 0) {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld host%@ blocked", ruleCount, (ruleCount == 1 ? @"" : @"s")];
			cell.detailTextLabel.textColor = [self colorForMenuTextHighlight];
		}
	}
	else if ([func isEqualToString:@"menuHTTPSEverywhere"] && haveURL) {
		long ruleCount = [[[[appDelegate webViewController] curWebViewTab] applicableHTTPSEverywhereRules] count];

		if (ruleCount > 0) {
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld rule%@ in use", ruleCount, (ruleCount == 1 ? @"" : @"s")];
			cell.detailTextLabel.textColor = [self colorForMenuTextHighlight];
		}
	}
	else if ([func isEqualToString:@"menuHostSettings"]) {
		HostSettings *hs = [HostSettings settingsOrDefaultsForHost:[[[[appDelegate webViewController] curWebViewTab] url] host]];
		if (hs && ![hs isDefault]) {
            cell.detailTextLabel.text = NSLocalizedString(@"Custom settings", nil);
			cell.detailTextLabel.textColor = [self colorForMenuTextHighlight];
		}
		else {
            cell.detailTextLabel.text = NSLocalizedString(@"Using defaults", nil);
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

- (void)menuURLBlocker
{
	URLBlockerRuleController *ubrc = [[URLBlockerRuleController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:ubrc];
	[[appDelegate webViewController] presentViewController:navController animated:YES completion:nil];
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
	[[appDelegate webViewController] showBookmarksForEditing:YES];
}

- (void)menuSettings
{
	if (!appSettingsViewController) {
		appSettingsViewController = [[IASKAppSettingsViewController alloc] init];
		appSettingsViewController.delegate = [appDelegate webViewController];
		appSettingsViewController.showDoneButton = YES;
		appSettingsViewController.showCreditsFooter = NO;
		
#ifdef SHOW_DONATION_CONTROLLER
		if (![DonationViewController canMakeDonation])
			[appSettingsViewController setHiddenKeys:[NSSet setWithArray:@[ @"open_donation" ]]];
#else
		[appSettingsViewController setHiddenKeys:[NSSet setWithArray:@[ @"open_donation" ]]];
#endif
	}
	
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:appSettingsViewController];
	[[appDelegate webViewController] presentViewController:navController animated:YES completion:nil];
}

- (void)bridgeSettings
{
    BridgeViewController *bridgesVC = [[BridgeViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bridgesVC];

    [[appDelegate webViewController] presentViewController:navController animated:YES completion:nil];
}

- (void)menuShare
{
	TUSafariActivity *activity = [[TUSafariActivity alloc] init];
	UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[ [[[appDelegate webViewController] curWebViewTab] url] ] applicationActivities:@[ activity ]];
	
	UIPopoverPresentationController *popover = [avc popoverPresentationController];
	if (popover) {
		popover.sourceView = [[appDelegate webViewController] settingsButton];
		popover.sourceRect = CGRectMake(1, popover.sourceView.frame.size.height / 2, 1, 1);
		popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
	}

	[[appDelegate webViewController] presentViewController:avc animated:YES completion:nil];
}

- (UIColor *)colorForMenuTextHighlight
{
	if ([[appDelegate webViewController] darkInterface])
		return [UIColor yellowColor];
	else
		return [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
}

@end
