#import "AppDelegate.h"
#import "URLInterceptor.h"
#import "WebViewTab.h"

@implementation WebViewTab

float progress;

- (id)initWithFrame:(CGRect)frame controller:(WebViewController *)wvc
{
	_viewHolder = [[UIView alloc] initWithFrame:frame];
	
	_webView = [[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
	[_webView setDelegate:self];
	[_webView setScalesPageToFit:YES];
	[_webView setAutoresizesSubviews:YES];
	
	self.controller = wvc;
	
	/* swiping goes back and forward in current webview */
	UISwipeGestureRecognizer *swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRightAction:)];
	[swipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
	[swipeRight setDelegate:self];
	[self.webView addGestureRecognizer:swipeRight];
 
	UISwipeGestureRecognizer *swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeLeftAction:)];
	[swipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
	[swipeLeft setDelegate:self];
	[self.webView addGestureRecognizer:swipeLeft];

	_titleHolder = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
	[_titleHolder setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.75]];

	_title = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
	[_title setTextColor:[UIColor whiteColor]];
	[_title setFont:[UIFont boldSystemFontOfSize:12.0]];
	[_title setLineBreakMode:NSLineBreakByTruncatingTail];
	[_title setTextAlignment:NSTextAlignmentCenter];
	
	_closer = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
	[_closer setTextColor:[UIColor whiteColor]];
	[_closer setFont:[UIFont systemFontOfSize:19.0]];
	[_closer setText:[NSString stringWithFormat:@"%C", 0x2715]];

	[_viewHolder addSubview:_titleHolder];
	[_viewHolder addSubview:_title];
	[_viewHolder addSubview:_closer];
	[_viewHolder addSubview:_webView];
	
	[self updateFrame:frame];

	[self zoomNormal];
	
	[self setSecureMode:WebViewTabSecureModeInsecure];

	return self;
}

- (void)updateFrame:(CGRect)frame
{
	[self.viewHolder setFrame:frame];
	[self.webView setFrame:CGRectMake(0, frame.origin.y, frame.size.width, frame.size.height)];
	[self.titleHolder setFrame:CGRectMake(0, frame.origin.y - 20, frame.size.width, 22)];
	[self.title setFrame:CGRectMake(24, frame.origin.y - 16, frame.size.width - 8 - 24, 12)];
	[self.closer setFrame:CGRectMake(2, frame.origin.y - 18, 18, 18)];
}

- (void)loadURL:(NSURL *)u
{
	[self setUrl:u];
	[self.webView stopLoading];
	
	NSMutableURLRequest *ur = [NSMutableURLRequest requestWithURL:u];
	[NSURLProtocol setProperty:[NSString stringWithFormat:@"%lu", (unsigned long)[self hash]] forKey:@"WebViewTab" inRequest:ur];
	
	/* remember that this was the directly entered URL */
	[NSURLProtocol setProperty:@YES forKey:ORIGIN_KEY inRequest:ur];
	
	[self setSecureMode:WebViewTabSecureModeInsecure];
	
	[self.webView loadRequest:ur];
}

- (void)webViewDidStartLoad:(UIWebView *)__webView
{
	[self setProgress:0.1];
}

- (void)webViewDidFinishLoad:(UIWebView *)__webView
{
#ifdef TRACE
	NSLog(@"[Tab %@] finished loading page/iframe %@", self.tabNumber, [[[__webView request] URL] absoluteString]);
#endif
	[self setProgress:1.0];
	
	[self.title setText:[[self webView] stringByEvaluatingJavaScriptFromString:@"document.title"]];
	
	[(AppDelegate *)[[UIApplication sharedApplication] delegate] dumpCookies];
}

- (void)webView:(UIWebView *)__webView didFailLoadWithError:(NSError *)error
{
	if (error.code != NSURLErrorCancelled) {
		UIAlertView *m = [[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:self cancelButtonTitle: @"Ok" otherButtonTitles:nil];
		[m show];
	}
	
	[self webViewDidFinishLoad:__webView];
}

- (BOOL)webView:(UIWebView *)__webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	/* TODO: intercept javascript window.open and <a target="_blank"> to open in a new tab */
	
	return YES;
}

- (void)setProgress:(float)pr
{
	progress = pr;
	[[self controller] updateProgress];
}

- (float)progress
{
	return progress;
}

- (void)swipeRightAction:(id)_id
{
	[self goBack];
}

- (void)swipeLeftAction:(id)_id
{
	[self goForward];
}

- (BOOL)canGoBack
{
	return !!(self.webView && [self.webView canGoBack]);
}

- (BOOL)canGoForward
{
	return !!(self.webView && [self.webView canGoForward]);
}

- (void)goBack
{
	if ([self.webView canGoBack])
		[self.webView goBack];
}

- (void)goForward
{
	if ([self.webView canGoForward])
		[self.webView goForward];
}

- (void)zoomOut
{
	self.webView.userInteractionEnabled = NO;
	[[self.webView layer] setBorderColor:[[UIColor grayColor] CGColor]];
	[[self.webView layer] setBorderWidth:0.5];

	[_titleHolder setHidden:false];
	[_title setHidden:false];
	[_closer setHidden:false];
	[[self viewHolder] setTransform:CGAffineTransformMakeScale(ZOOM_OUT_SCALE, ZOOM_OUT_SCALE)];
}

- (void)zoomNormal
{
	self.webView.userInteractionEnabled = YES;
	[[self.webView layer] setBorderWidth:0];

	[_titleHolder setHidden:true];
	[_title setHidden:true];
	[_closer setHidden:true];
	[[self viewHolder] setTransform:CGAffineTransformMakeScale(1.0, 1.0)];
}

@end
