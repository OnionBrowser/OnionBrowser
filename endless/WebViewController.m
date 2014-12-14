#import "AppDelegate.h"
#import "WebViewController.h"
#import "NJKWebViewProgress.h"
#import "IASKAppSettingsViewController.h"
#import "URLInterceptor.h"

@interface WebViewController ()

@end

@implementation WebViewController {
	IBOutlet UISearchBar *searchBar;
	IBOutlet UIProgressView *progressBar;
	IBOutlet UIWebView *webView;
	IBOutlet UIToolbar *toolbar;
	
	IBOutlet UIBarButtonItem *backButton;
	IBOutlet UIBarButtonItem *forwardButton;
	IBOutlet UIBarButtonItem *shareButton;
	IBOutlet UIBarButtonItem *bookmarksButton;
	IBOutlet UIBarButtonItem *tabsButton;
	IBOutlet UIBarButtonItem *settingsButton;

	NJKWebViewProgress *_progressProxy;
	AppDelegate *appDelegate;
	
	IASKAppSettingsViewController *appSettingsViewController;
	
	float lastWebViewScrollOffset;
	CGFloat toolbarHeight;
	BOOL webViewScrollIsDecelerating;
	BOOL webViewScrollIsDragging;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate setCurWebView:self];
	
	toolbarHeight = toolbar.bounds.size.height;
	[webView.scrollView setContentInset:UIEdgeInsetsMake(0, 0, toolbarHeight, 0)];
	[webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, toolbarHeight, 0)];
	[webView.scrollView setDelegate:self];
	
	_progressProxy = [[NJKWebViewProgress alloc] init];
	webView.delegate = _progressProxy;
	_progressProxy.webViewProxyDelegate = self;
	_progressProxy.progressDelegate = self;
	
	/* hook up toolbar buttons */
	backButton.target = self;
	backButton.action = @selector(goBack:);
	forwardButton.target = self;
	forwardButton.action = @selector(goForward:);
	settingsButton.target = self;
	settingsButton.action = @selector(showSettings:);
	
	/* swiping goes back and forward in current webview */
	UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self  action:@selector(swipeRightAction:)];
	swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
	swipeRight.delegate = self;
	[webView addGestureRecognizer:swipeRight];
 
	UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeftAction:)];
	swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
	swipeLeft.delegate = self;
	[webView addGestureRecognizer:swipeLeft];
	
	[[self searchBarTextField] setClearButtonMode:UITextFieldViewModeWhileEditing];
	[self updateSearchBarDetails];
	
	[self.view.window makeKeyAndVisible];
	
	[self navigateTo:[NSURL URLWithString:@"https://www.duckduckgo.com/"]];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}


- (void)navigateTo:(NSURL *)URL
{
	self.curURL = URL;
	[webView stopLoading];
	[webView loadRequest:[NSURLRequest requestWithURL:URL]];
	[self startedLoadingPage:URL];
}

- (void)updateSearchBarDetails
{
	NSString *evOrg;
	
	/* TODO: cache curURL and only do anything here if it changed, these changes might be expensive */

	if (searchBar.isFirstResponder) {
		/* focused, don't muck with the URL while it's being edited */
		
		[[self searchBarTextField] setTextAlignment:NSTextAlignmentNatural];
		[[self searchBarTextField] setTextColor:[UIColor darkTextColor]];
		[searchBar setShowsCancelButton:YES animated:YES];
		[searchBar setImage:UISearchBarIconSearch forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
	}
	else {
		[self.searchBarTextField setTextAlignment:NSTextAlignmentCenter];
		[searchBar setShowsCancelButton:NO animated:YES];

		if (self.curURL != nil && [[self.curURL scheme] isEqualToString:@"https"]) {
			evOrg = [[appDelegate evHosts] objectForKey:[self.curURL host]];

			[searchBar setImage:[UIImage imageNamed:@"lock"] forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
		}
		else {
			/* XXX: is this legal? */
			[searchBar setImage:[UIImage new] forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
		}
		
		if (evOrg != nil && ![evOrg isEqualToString:@""] && [progressBar progress] == 0) {
			[[self searchBarTextField] setTextColor:[UIColor colorWithRed:0 green:(183.0/255.0) blue:(82.0/255.0) alpha:1.0]];
			
			[searchBar setText:evOrg];
		}
		else {
			NSString *host;
			if (self.curURL == nil)
				host = @"";
			else {
				host = [self.curURL host];
				if (host == nil)
					host = [self.curURL absoluteString];
			}
			
			NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^www\\d*\\." options:NSRegularExpressionCaseInsensitive error:nil];
			NSString *hostNoWWW = [regex stringByReplacingMatchesInString:host options:0 range:NSMakeRange(0, [host length]) withTemplate:@""];
			
			[[self searchBarTextField] setTextColor:[UIColor darkTextColor]];
			[searchBar setText:hostNoWWW];
		}
	}
}

- (UITextField *)searchBarTextField
{
	for (UIView *subView in searchBar.subviews) {
		for(id field in subView.subviews){
			if ([field isKindOfClass:[UITextField class]]) {
				UITextField *textField = (UITextField *)field;
				return textField;
			}
		}
	}
	return nil;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return 1;
}


- (void)webViewProgress:(NJKWebViewProgress *)webViewProgress updateProgress:(float)progress
{
	BOOL animated = YES;
	float fadeAnimationDuration = 0.27f;
	float fadeOutDelay = 1.0f;
	
#ifdef TRACE
	NSLog(@"loading progress of %@ at %f", [self.curURL absoluteString], progress);
#endif

	[self updateSearchBarDetails];
	
	[progressBar setProgress:progress animated:animated];

	if (progress >= NJKFinalProgressValue) {
		[progressBar setProgress:progress animated:NO];

		[UIView animateWithDuration:fadeAnimationDuration delay:fadeOutDelay options:UIViewAnimationOptionCurveEaseInOut animations:^{
			progressBar.alpha = 0.0;
		} completion:^(BOOL finished) {
			progressBar.progress = 0;
			[self updateSearchBarDetails];
		}];
	}
	else {
		[UIView animateWithDuration:(animated ? fadeAnimationDuration : 0.0) delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
			progressBar.alpha = 1.0;
		} completion:nil];
	}
}

- (void)webViewDidFinishLoad:(UIWebView *)_webView
{
#ifdef TRACE
	NSLog(@"finished loading page/iframe %@", [[[_webView request] URL] absoluteString]);
#endif
	[self updateSearchBarDetails];
	
#ifdef TRACE
	[appDelegate dumpCookies];
#endif
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	UIAlertView *m = [[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:self cancelButtonTitle: @"Ok" otherButtonTitles:nil];
	[m show];
	
	[self webViewProgress:_progressProxy updateProgress:NJKFinalProgressValue];

	/* TODO: where do we get the correct URL from now? */
	
	[self updateSearchBarDetails];
}


- (void)startedLoadingPage:(NSURL *)url
{
#ifdef TRACE
	NSLog(@"started loading URL %@", url);
#endif
	/* just in case it redirected? */
	self.curURL = url;

	[self updateSearchBarDetails];
	
	[progressBar setProgress:NJKInitialProgressValue animated:NO];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)_searchBar
{
#ifdef TRACE
	NSLog(@"started editing");
#endif
	UITextField *sbtf = [self searchBarTextField];
	[sbtf setTextAlignment:NSTextAlignmentNatural];
	
	[searchBar setText:[self.curURL absoluteString]];
	[self updateSearchBarDetails];
	
	[sbtf performSelector:@selector(selectAll:) withObject:nil afterDelay:0.0];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)_searchBar
{
#ifdef TRACE
	NSLog(@"ended editing with \"%@\"", [_searchBar text]);
#endif
	UITextField *sbtf = [self searchBarTextField];
	[sbtf setTextAlignment:NSTextAlignmentCenter];
	
	[self updateSearchBarDetails];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)_searchBar
{
#ifdef TRACE
	NSLog(@"cancel button clicked");
#endif
	[searchBar resignFirstResponder];
}

- (void)searchBarResultsListButtonClicked:(UISearchBar *)searchBar
{
	NSLog(@"results list button clicked");
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)_searchBar
{
	NSURL *enteredURL = [NSURL URLWithString:searchBar.text];
	if (![enteredURL scheme] || [[enteredURL scheme] isEqualToString:@""])
		enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", searchBar.text]];
	
#ifdef TRACE
	NSLog(@"search button clicked, loading %@", enteredURL);
#endif
	
	[searchBar resignFirstResponder]; /* will unfocus and call searchBarTextDidEndEditing */

	[self navigateTo:enteredURL];
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView
{
	if (scrollView != webView.scrollView)
		return;
	
	if (scrollView.contentOffset.y < 0)
		lastWebViewScrollOffset = 0;
	
	if (!webViewScrollIsDragging) {
		lastWebViewScrollOffset = scrollView.contentOffset.y;
		return;
	}

	float y = toolbar.frame.origin.y;
	
	if (lastWebViewScrollOffset < scrollView.contentOffset.y) {
		/* scrolling down the page, content moving up, always start hiding bar */
		y += (scrollView.contentOffset.y - lastWebViewScrollOffset) * 0.75;
	}
	/* scrolling up, require a big jump to initiate, then fully show the bar */
	else if ((lastWebViewScrollOffset - scrollView.contentOffset.y) >= 3) {
		[UIView animateWithDuration:0.3
				      delay:0.0
				    options:UIViewAnimationOptionCurveEaseOut
				 animations:^(void) {
					 CGRect toolbarFrame = CGRectMake(0, self.view.bounds.size.height - toolbarHeight, self.view.bounds.size.width, toolbarHeight);
					 toolbar.frame = toolbarFrame;
				 }
				 completion:^(BOOL finished) {
					 CGRect toolbarFrame = CGRectMake(0, self.view.bounds.size.height - toolbarHeight, self.view.bounds.size.width, toolbarHeight);
					 toolbar.frame = toolbarFrame;
					 lastWebViewScrollOffset = scrollView.contentOffset.y;
				 }];
	}
	
	y = MAX(self.view.bounds.size.height - toolbarHeight, y);
	y = MIN(self.view.bounds.size.height, y);

	CGRect toolbarFrame = CGRectMake(0, y, self.view.bounds.size.width, toolbarHeight);
	toolbar.frame = toolbarFrame;
	
	if (y >= self.view.bounds.size.height - toolbarHeight) {
		[webView.scrollView setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
		[webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
	} else {
		[webView.scrollView setContentInset:UIEdgeInsetsMake(0, 0, toolbarHeight, 0)];
		[webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, toolbarHeight, 0)];
	}
	
	lastWebViewScrollOffset = scrollView.contentOffset.y;
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	if (scrollView == webView.scrollView)
		webViewScrollIsDragging = YES;
}

- (void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (scrollView == webView.scrollView)
		webViewScrollIsDragging = NO;
}

- (void) scrollViewWillBeginDecelerating:(UIScrollView *)scrollView
{
	if (scrollView == webView.scrollView)
		webViewScrollIsDecelerating = YES;
}

- (void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	if (scrollView == webView.scrollView)
		webViewScrollIsDecelerating = NO;
}

- (void)swipeRightAction:(id)_id
{
	[self goBack:nil];
}
- (void)swipeLeftAction:(id)_id
{
	[self goForward:nil];
}

- (void)goBack:(id)_id
{
	if ([webView canGoBack])
		[webView goBack];
}

- (void)goForward:(id)_id
{
	if ([webView canGoForward])
		[webView goForward];
}

- (void)showSettings:(id)_id
{
	if (!appSettingsViewController) {
		appSettingsViewController = [[IASKAppSettingsViewController alloc] init];
		appSettingsViewController.delegate = self;
		appSettingsViewController.showDoneButton = YES;
		appSettingsViewController.showCreditsFooter = NO;
	}
	
	UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:appSettingsViewController];
	[self presentViewController:aNavController animated:YES completion:nil];
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[URLInterceptor setSendDNT:[userDefaults boolForKey:@"send_dnt"]];
}

@end
