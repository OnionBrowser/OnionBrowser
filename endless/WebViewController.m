#import "WebViewController.h"
#import "NJKWebViewProgress.h"

@interface WebViewController ()

@end

@implementation WebViewController {
	IBOutlet UISearchBar *searchBar;
	IBOutlet UIProgressView *progressBar;
	IBOutlet UIWebView *webView;
	
	NJKWebViewProgress *_progressProxy;
}

NSURL *curURL;

- (void)viewDidLoad {
	[super viewDidLoad];
	
	_progressProxy = [[NJKWebViewProgress alloc] init];
	webView.delegate = _progressProxy;
	_progressProxy.webViewProxyDelegate = self;
	_progressProxy.progressDelegate = self;
	
	UITextField *sbtf = [self searchBarTextField];
	[sbtf setTextAlignment:NSTextAlignmentCenter];

	[webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.google.com/"]]];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
#ifdef DEBUG
	NSLog(@"loading page/iframe %@", [[request URL] absoluteString]);
#endif
	
	if (curURL == nil || [[curURL absoluteString] isEqualToString:[[request mainDocumentURL] absoluteString]]) {
		[self startedLoadingPage:[request mainDocumentURL]];
	}
	
	return YES;
}

- (void)webViewProgress:(NJKWebViewProgress *)webViewProgress updateProgress:(float)progress
{
	BOOL animated = YES;
	float fadeAnimationDuration = 0.27f;
	float fadeOutDelay = 0.1f;

	[progressBar setProgress:progress animated:animated];
	
	if (progress >= 1.0) {
		[UIView animateWithDuration:(animated ? fadeAnimationDuration : 0.0) delay:fadeOutDelay options:UIViewAnimationOptionCurveEaseInOut animations:^{
			progressBar.alpha = 0.0;
		} completion:nil];
	}
	else {
		[UIView animateWithDuration:(animated ? fadeAnimationDuration : 0.0) delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
			progressBar.alpha = 1.0;
		} completion:nil];
	}
}

- (void)startedLoadingPage:(NSURL *)page {
	curURL = page;
	
	[self showShortURL];
	
	[progressBar setProgress:NJKInitialProgressValue animated:NO];
	
	if ([[curURL scheme] isEqualToString:@"https"]) {
		/* TODO: color this green when the ssl cert is extended validation */
		[searchBar setImage:[UIImage imageNamed:@"lock"] forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
	}
	else {
	}
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)_searchBar {
#ifdef DEBUG
	NSLog(@"started editing");
#endif
	UITextField *sbtf = [self searchBarTextField];

	[sbtf setTextAlignment:NSTextAlignmentNatural];
	[searchBar setText:[curURL absoluteString]];
	
	[sbtf performSelector:@selector(selectAll:) withObject:nil afterDelay:0.0];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)_searchBar {
#ifdef DEBUG
	NSLog(@"ended editing");
#endif
	UITextField *sbtf = [self searchBarTextField];
	[sbtf setTextAlignment:NSTextAlignmentCenter];

	[self showShortURL];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)_searchBar {
	NSURL *enteredURL = [NSURL URLWithString:searchBar.text];
	if (![enteredURL scheme] || [[enteredURL scheme] isEqualToString:@""])
		enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", searchBar.text]];
	
#ifdef DEBUG
	NSLog(@"search button clicked, loading %@", enteredURL);
#endif
	curURL = enteredURL;
	
	[self searchBarTextDidEndEditing:searchBar];
	[searchBar resignFirstResponder];
	
	[webView stopLoading];
	[webView loadRequest:[NSURLRequest requestWithURL:enteredURL]];
}

- (void)showShortURL {
	NSString *host = [curURL host];

	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^www\\d*\\." options:NSRegularExpressionCaseInsensitive error:nil];
	NSString *hostNoWWW = [regex stringByReplacingMatchesInString:host options:0 range:NSMakeRange(0, [host length]) withTemplate:@""];
	
	[searchBar setText:hostNoWWW];
}

-(UITextField *)searchBarTextField {
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

@end
