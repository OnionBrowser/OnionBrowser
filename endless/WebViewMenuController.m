#import "AppDelegate.h"
#import "IASKAppSettingsViewController.h"
#import "HTTPSEverywhereRuleController.h"
#import "WebViewMenuController.h"

@implementation WebViewMenuController

AppDelegate *appDelegate;
IASKAppSettingsViewController *appSettingsViewController;
NSDictionary *buttons;

enum WebViewMenuButton {
	WebViewMenuButtonRefresh,
	WebViewMenuButtonCookies,
	WebViewMenuButtonHTTPSEverywhere,
	WebViewMenuButtonSettings,
	
	WebViewMenuButtonCount,
} WebViewMenuButton;

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	buttons = @{
		    [NSNumber numberWithInt:WebViewMenuButtonRefresh] : @"Refresh",
		    [NSNumber numberWithInt:WebViewMenuButtonCookies] : @"Cookies",
		    [NSNumber numberWithInt:WebViewMenuButtonHTTPSEverywhere] : @"HTTPS Everywhere",
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
	return CGSizeMake(150, [self tableView:nil heightForRowAtIndexPath:nil] * [buttons count]);
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [buttons count];
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
		[cell setSeparatorInset:UIEdgeInsetsZero];
	}
	if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
		[cell setPreservesSuperviewLayoutMargins:NO];
	}
	if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
		[cell setLayoutMargins:UIEdgeInsetsZero];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"button"];
	long ruleCount;

	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"button"];
	}
	
	cell.backgroundColor = [UIColor clearColor];
	cell.textLabel.font = [UIFont systemFontOfSize:13];
	cell.textLabel.text = [buttons objectForKey:[NSNumber numberWithLong:[indexPath row]]];
	
	cell.detailTextLabel.font = [UIFont systemFontOfSize:11];

	switch ([indexPath row]) {
	case WebViewMenuButtonCookies:
		if ([[appDelegate cookieWhitelist] isHostWhitelisted:[[[[appDelegate webViewController] curWebViewTab] url] host]]) {
			cell.detailTextLabel.text = @"Whitelisted";
			cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:0.5 blue:0 alpha:1];
		}
		else {
			cell.detailTextLabel.text = @"Session-only";
			cell.detailTextLabel.textColor = [UIColor darkTextColor];
		}
		break;
	
	case WebViewMenuButtonHTTPSEverywhere:
		ruleCount = [[[[appDelegate webViewController] curWebViewTab] applicableHTTPSEverywhereRules] count];

		if (ruleCount > 0) {
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
	[[appDelegate webViewController] refresh];
}

- (void)menuSettings
{
	if (!appSettingsViewController) {
		appSettingsViewController = [[IASKAppSettingsViewController alloc] init];
		appSettingsViewController.delegate = [appDelegate webViewController];
		appSettingsViewController.showDoneButton = YES;
		appSettingsViewController.showCreditsFooter = NO;
	}
	
	UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:appSettingsViewController];
	[[appDelegate webViewController] presentViewController:aNavController animated:YES completion:nil];
}

- (void)menuHTTPSEverywhere
{
	UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:[[HTTPSEverywhereRuleController alloc] init]];
	[[appDelegate webViewController] presentViewController:aNavController animated:YES completion:nil];
}

@end
