#import "AppDelegate.h"
#import "Bookmark.h"
#import "BookmarkController.h"
#import "CookieController.h"
#import "IASKAppSettingsViewController.h"
#import "HTTPSEverywhereRuleController.h"
#import "WebViewMenuController.h"

@implementation WebViewMenuController

AppDelegate *appDelegate;
IASKAppSettingsViewController *appSettingsViewController;
NSDictionary *buttons;

enum WebViewMenuButton {
	WebViewMenuButtonRefresh,
	WebViewMenuButtonAddBookmark,
	WebViewMenuButtonCookies,
	WebViewMenuButtonHTTPSEverywhere,
	WebViewMenuButtonManageBookmarks,
	WebViewMenuButtonSettings,
	
	WebViewMenuButtonCount,
} WebViewMenuButton;

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	buttons = @{
		    [NSNumber numberWithInt:WebViewMenuButtonRefresh] : @"Refresh",
		    [NSNumber numberWithInt:WebViewMenuButtonAddBookmark] : @"Add Bookmark",
		    [NSNumber numberWithInt:WebViewMenuButtonCookies] : @"Cookies",
		    [NSNumber numberWithInt:WebViewMenuButtonHTTPSEverywhere] : @"HTTPS Everywhere",
		    [NSNumber numberWithInt:WebViewMenuButtonManageBookmarks] : @"Manage Bookmarks",
		    [NSNumber numberWithInt:WebViewMenuButtonSettings] : @"Settings",
	};
	
	[self.view setBackgroundColor:[UIColor clearColor]];
	[self.tableView setSeparatorInset:UIEdgeInsetsZero];
}

- (void)viewWillDisappear:(BOOL)animated
{
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
	long ruleCount;

	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"button"];
	
	cell.backgroundColor = [UIColor clearColor];
	cell.textLabel.font = [UIFont systemFontOfSize:13];
	cell.textLabel.text = [buttons objectForKey:[NSNumber numberWithLong:[indexPath row]]];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:11];
	
	BOOL haveURL = ([[[appDelegate webViewController] curWebViewTab] url] != nil);

	switch ([indexPath row]) {
	case WebViewMenuButtonAddBookmark:
		if (haveURL) {
			if ([Bookmark isURLBookmarked:[[[appDelegate webViewController] curWebViewTab] url]]) {
				cell.textLabel.text = @"Bookmarked";
				cell.userInteractionEnabled = cell.textLabel.enabled = NO;
			}
		}
		else
			cell.userInteractionEnabled = cell.textLabel.enabled = NO;
			
		break;

	case WebViewMenuButtonRefresh:
		cell.userInteractionEnabled = haveURL;
		cell.textLabel.enabled = haveURL;
		break;
			
	case WebViewMenuButtonCookies:
		if (haveURL) {
			if ([[appDelegate cookieJar] isHostWhitelisted:[[[[appDelegate webViewController] curWebViewTab] url] host]]) {
				cell.detailTextLabel.text = @"Whitelisted";
				cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
			}
			else {
				cell.detailTextLabel.text = @"Session-only";
				cell.detailTextLabel.textColor = [UIColor darkTextColor];
			}
		}

		break;
	
	case WebViewMenuButtonHTTPSEverywhere:
		if (haveURL) {
			ruleCount = [[[[appDelegate webViewController] curWebViewTab] applicableHTTPSEverywhereRules] count];

			if (ruleCount > 0)
				cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld Rule%@ Applied", ruleCount, (ruleCount == 1 ? @"" : @"s")];
		}
			
		break;
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
	
	/* "Show Cookies" -> @selector(menuShowCookies) */
	SEL action = NSSelectorFromString([NSString stringWithFormat:@"menu%@", [[buttons objectForKey:[NSNumber numberWithLong:[indexPath row]]] stringByReplacingOccurrencesOfString:@" " withString:@""]]);
	
	if ([self respondsToSelector:action]) {
		[self performSelector:action];
	}
	else {
		NSLog(@"can't call %@", NSStringFromSelector(action));
	}
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

@end
