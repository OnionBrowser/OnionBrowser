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
}

- (void)viewDidLoad {
	[super viewDidLoad];

	AppDelegate *app = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	[app setCurWebView:self];
	
	_progressProxy = [[NJKWebViewProgress alloc] init];
	webView.delegate = _progressProxy;
	_progressProxy.webViewProxyDelegate = self;
	_progressProxy.progressDelegate = self;
	
	UITextField *sbtf = [self searchBarTextField];
	[sbtf setTextAlignment:NSTextAlignmentCenter];
	
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

- (void)updateSearchBarIcon {
	if (searchBar.isFirstResponder) {
		/* focused, just set default */
		[searchBar setImage:UISearchBarIconSearch forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
	} else {
		if ([[self.curURL scheme] isEqualToString:@"https"]) {
			/* TODO: color this green when the ssl cert is extended validation */
			[searchBar setImage:[UIImage imageNamed:@"lock"] forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
		}
		else {
			/* XXX: is this legal? */
			[searchBar setImage:[UIImage new] forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
		}
	}
}

- (void)showShortURL {
	NSString *host = [self.curURL host];
	if (host == nil)
		host = [self.curURL absoluteString];
	
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


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return 1;
}


- (void)webViewProgress:(NJKWebViewProgress *)webViewProgress updateProgress:(float)progress
{
	BOOL animated = YES;
	float fadeAnimationDuration = 0.27f;
	float fadeOutDelay = 1.0f;
	
#ifdef DEBUG
	NSLog(@"loading progress of %@ at %f", [self.curURL absoluteString], progress);
#endif

	[progressBar setProgress:progress animated:animated];
	[self updateSearchBarIcon];
	
	if (progress >= 1.0) {
		[progressBar setProgress:progress animated:NO];

		[UIView animateWithDuration:fadeAnimationDuration delay:fadeOutDelay options:UIViewAnimationOptionCurveEaseInOut animations:^{
			progressBar.alpha = 0.0;
		} completion:nil];
	}
	else {
		[UIView animateWithDuration:(animated ? fadeAnimationDuration : 0.0) delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
			progressBar.alpha = 1.0;
		} completion:nil];
	}
}

- (void)webViewDidFinishLoad:(UIWebView *)_webView {
#ifdef DEBUG
	NSLog(@"finished loading page/iframe %@", [[[_webView request] URL] absoluteString]);
#endif
}


- (void)startedLoadingPage:(NSURL *)page {
#ifdef DEBUG
	NSLog(@"started loading page %@", page);
#endif
	/* just in case it redirected? */
	self.curURL = page;

	[self showShortURL];
	
	[progressBar setProgress:NJKInitialProgressValue animated:NO];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)_searchBar {
#ifdef DEBUG
	NSLog(@"started editing");
#endif
	UITextField *sbtf = [self searchBarTextField];
	[sbtf setTextAlignment:NSTextAlignmentNatural];
	
	[searchBar setText:[self.curURL absoluteString]];
	[self updateSearchBarIcon];
	
	[sbtf performSelector:@selector(selectAll:) withObject:nil afterDelay:0.0];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)_searchBar {
#ifdef DEBUG
	NSLog(@"ended editing with \"%@\"", [_searchBar text]);
#endif
	UITextField *sbtf = [self searchBarTextField];
	[sbtf setTextAlignment:NSTextAlignmentCenter];
	
	[self showShortURL];
	
	[self updateSearchBarIcon];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)_searchBar {
	NSURL *enteredURL = [NSURL URLWithString:searchBar.text];
	if (![enteredURL scheme] || [[enteredURL scheme] isEqualToString:@""])
		enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", searchBar.text]];
	
#ifdef DEBUG
	NSLog(@"search button clicked, loading %@", enteredURL);
#endif
	
	[searchBar resignFirstResponder]; /* will unfocus and call searchBarTextDidEndEditing */

	[self navigateTo:enteredURL];
}

@end
