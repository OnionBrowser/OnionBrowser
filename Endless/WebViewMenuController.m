#import "AppDelegate.h"
#import "Bookmark.h"
#import "BookmarkController.h"
#import "CookieController.h"
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

	[buttons addObject:@{ FUNC : @"menuAddBookmark", LABEL : @"Add Bookmark" }];
	[buttons addObject:@{ FUNC : @"menuOpenInSafari", LABEL : @"Open in Safari" }];
	[buttons addObject:@{ FUNC : @"menuCookies", LABEL : @"Cookies" }];
	[buttons addObject:@{ FUNC : @"menuHTTPSEverywhere", LABEL : @"HTTPS Everywhere" }];
	[buttons addObject:@{ FUNC : @"menuManageBookmarks", LABEL : @"Manage Bookmarks" }];
	[buttons addObject:@{ FUNC : @"menuSettings", LABEL : @"Settings" }];
	
	[self.view setBackgroundColor:[UIColor clearColor]];
	[self.tableView setSeparatorInset:UIEdgeInsetsZero];
}

- (CGSize)preferredContentSize
{
	return CGSizeMake(160, [self tableView:nil heightForRowAtIndexPath:nil] * [buttons count]);
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
	cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
	
	BOOL haveURL = ([[[appDelegate webViewController] curWebViewTab] url] != nil);

	NSString *func = [button objectForKey:FUNC];
	if ([func isEqualToString:@"menuAddBookmark"]) {
		if (haveURL) {
			if ([Bookmark isURLBookmarked:[[[appDelegate webViewController] curWebViewTab] url]]) {
				cell.textLabel.text = @"Bookmarked";
				cell.userInteractionEnabled = cell.textLabel.enabled = NO;
			}
		}
		else
			cell.userInteractionEnabled = cell.textLabel.enabled = NO;
	}
	else if ([func isEqualToString:@"menuOnePassword"] || [func isEqualToString:@"menuRefresh"] || [func isEqualToString:@"menuOpenInSafari"]) {
		cell.userInteractionEnabled = haveURL;
		cell.textLabel.enabled = haveURL;
	}
	else if ([func isEqualToString:@"menuCookies"] && haveURL) {
		if ([[appDelegate cookieJar] isHostWhitelisted:[[[[appDelegate webViewController] curWebViewTab] url] host]]) {
			cell.detailTextLabel.text = @"Whitelisted";
			cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
		}
		else {
			cell.detailTextLabel.text = @"Session-only";
			cell.detailTextLabel.textColor = [UIColor darkTextColor];
		}
	}
	else if ([func isEqualToString:@"menuHTTPSEverywhere"] && haveURL) {
		long ruleCount = [[[[appDelegate webViewController] curWebViewTab] applicableHTTPSEverywhereRules] count];

		if (ruleCount > 0)
			cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld Rule%@ Applied", ruleCount, (ruleCount == 1 ? @"" : @"s")];
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

- (void)menuRefresh
{
	[[appDelegate webViewController] forceRefresh];
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

- (void)menuCookies
{
	CookieController *cc = [[CookieController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:cc];
	[[appDelegate webViewController] presentViewController:navController animated:YES completion:nil];
}

- (void)menuHTTPSEverywhere
{
	HTTPSEverywhereRuleController *herc = [[HTTPSEverywhereRuleController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:herc];
	[[appDelegate webViewController] presentViewController:navController animated:YES completion:nil];
}

- (void)menuManageBookmarks
{
	BookmarkController *bc = [[BookmarkController alloc] init];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bc];
	[[appDelegate webViewController] presentViewController:navController animated:YES completion:nil];
}

- (void)menuAddBookmark
{
	[[appDelegate webViewController] presentViewController:[Bookmark addBookmarkDialogWithOkCallback:nil] animated:YES completion:nil];
}

- (void)menuOnePassword
{
	[[OnePasswordExtension sharedExtension] fillItemIntoWebView:[[[appDelegate webViewController] curWebViewTab] webView] forViewController:[appDelegate webViewController] sender:nil showOnlyLogins:NO completion:^(BOOL success, NSError *error) {
		if (!success)
			NSLog(@"[OnePasswordExtension] failed to fill into webview: %@", error);
	}];
}

- (void)menuOpenInSafari
{
	WebViewTab *wvt = [[appDelegate webViewController] curWebViewTab];
	if (wvt && [wvt url])
		[[UIApplication sharedApplication] openURL:[wvt url]];
}

@end
