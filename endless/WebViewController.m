#import "AppDelegate.h"
#import "WebViewController.h"
#import "NJKWebViewProgress.h"

@interface WebViewController ()

@end

@implementation WebViewController {
	IBOutlet UISearchBar *searchBar;
	IBOutlet UIProgressView *progressBar;
	IBOutlet UIWebView *webView;
	
	NJKWebViewProgress *_progressProxy;
	AppDelegate *appDelegate;
}

- (void)viewDidLoad {
	[super viewDidLoad];

	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate setCurWebView:self];
	
	_progressProxy = [[NJKWebViewProgress alloc] init];
	webView.delegate = _progressProxy;
	_progressProxy.webViewProxyDelegate = self;
	_progressProxy.progressDelegate = self;
	
	/* swiping goes back and forward in current webview */
	UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self  action:@selector(swipeRightAction:)];
	swipeRight.direction = UISwipeGestureRecognizerDirectionRight;
	swipeRight.delegate = self;
	[webView addGestureRecognizer:swipeRight];
 
	UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeftAction:)];
	swipeLeft.direction = UISwipeGestureRecognizerDirectionLeft;
	swipeLeft.delegate = self;
	[webView addGestureRecognizer:swipeLeft];
	
	[self navigateTo:[NSURL URLWithString:@"https://duckduckgo.com/"]];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}


- (void)navigateTo:(NSURL *)URL {
	self.curURL = URL;
	[webView stopLoading];
	[webView loadRequest:[NSURLRequest requestWithURL:URL]];
	[self startedLoadingPage:URL];
}

- (void)updateSearchBarDetails {
	NSString *evOrg;
	
	/* TODO: cache curURL and only do anything here if it changed, these changes might be expensive */

	if (searchBar.isFirstResponder) {
		/* focused, don't muck with the URL while it's being edited */
		
		[[self searchBarTextField] setTextAlignment:NSTextAlignmentNatural];
		[[self searchBarTextField] setTextColor:[UIColor darkTextColor]];
		[searchBar setImage:UISearchBarIconSearch forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
	}
	else {
		[self.searchBarTextField setTextAlignment:NSTextAlignmentCenter];

		if ([[self.curURL scheme] isEqualToString:@"https"]) {
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
			NSString *host = [self.curURL host];
			if (host == nil)
				host = [self.curURL absoluteString];
			
			NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^www\\d*\\." options:NSRegularExpressionCaseInsensitive error:nil];
			NSString *hostNoWWW = [regex stringByReplacingMatchesInString:host options:0 range:NSMakeRange(0, [host length]) withTemplate:@""];
			
			[[self searchBarTextField] setTextColor:[UIColor darkTextColor]];
			[searchBar setText:hostNoWWW];
		}
	}
}

- (UITextField *)searchBarTextField {
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


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
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

- (void)webViewDidFinishLoad:(UIWebView *)_webView {
#ifdef TRACE
	NSLog(@"finished loading page/iframe %@", [[[_webView request] URL] absoluteString]);
#endif
	[self updateSearchBarDetails];
	
#ifdef DEBUG
	NSLog(@"cookie dump:");
#endif
	for (NSHTTPCookie *cookie in [[appDelegate cookieStorage] cookies]) {
#ifdef DEBUG
		NSLog(@"  %@: \"%@\"=\"%@\"", cookie.domain, cookie.name, cookie.value);
#endif
		[[appDelegate cookieStorage] deleteCookie:cookie];
	}
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
	UIAlertView *m = [[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:self cancelButtonTitle: @"Ok" otherButtonTitles:nil];
	[m show];
	
	[self webViewProgress:_progressProxy updateProgress:NJKFinalProgressValue];

	/* TODO: where do we get the correct URL from now? */
	
	[self updateSearchBarDetails];
}


- (void)startedLoadingPage:(NSURL *)url {
#ifdef TRACE
	NSLog(@"started loading URL %@", url);
#endif
	/* just in case it redirected? */
	self.curURL = url;

	[self updateSearchBarDetails];
	
	[progressBar setProgress:NJKInitialProgressValue animated:NO];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)_searchBar {
#ifdef TRACE
	NSLog(@"started editing");
#endif
	UITextField *sbtf = [self searchBarTextField];
	[sbtf setTextAlignment:NSTextAlignmentNatural];
	
	[searchBar setText:[self.curURL absoluteString]];
	[self updateSearchBarDetails];
	
	[sbtf performSelector:@selector(selectAll:) withObject:nil afterDelay:0.0];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)_searchBar {
#ifdef TRACE
	NSLog(@"ended editing with \"%@\"", [_searchBar text]);
#endif
	UITextField *sbtf = [self searchBarTextField];
	[sbtf setTextAlignment:NSTextAlignmentCenter];
	
	[self updateSearchBarDetails];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)_searchBar {
	NSURL *enteredURL = [NSURL URLWithString:searchBar.text];
	if (![enteredURL scheme] || [[enteredURL scheme] isEqualToString:@""])
		enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", searchBar.text]];
	
#ifdef TRACE
	NSLog(@"search button clicked, loading %@", enteredURL);
#endif
	
	[searchBar resignFirstResponder]; /* will unfocus and call searchBarTextDidEndEditing */

	[self navigateTo:enteredURL];
}


- (void)swipeRightAction:(id)_id {
	if ([webView canGoBack])
		[webView goBack];
}
- (void)swipeLeftAction:(id)_id {
	if ([webView canGoForward])
		[webView goForward];
}

@end
