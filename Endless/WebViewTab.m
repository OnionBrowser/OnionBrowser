#import "AppDelegate.h"
#import "URLInterceptor.h"
#import "WebViewTab.h"
#import "NSString+JavascriptEscape.h"

@import WebKit;

@implementation WebViewTab

static NSString *_javascriptToInject;

AppDelegate *appDelegate;

+ (NSString *)javascriptToInject
{
	if (!_javascriptToInject) {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"injected" ofType:@"js"];
		_javascriptToInject = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	}
	
	return _javascriptToInject;
}

+ (WebViewTab *)openedWebViewTabByRandID:(NSString *)randID
{
	for (WebViewTab *wvt in [[appDelegate webViewController] webViewTabs]) {
		if ([wvt randID] != nil && [[wvt randID] isEqualToString:randID]) {
			return wvt;
		}
	}
	
	return nil;
}

- (id)initWithFrame:(CGRect)frame
{
	return [self initWithFrame:frame withRestorationIdentifier:nil];
}

- (id)initWithFrame:(CGRect)frame withRestorationIdentifier:(NSString *)rid
{
	self = [super init];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	_viewHolder = [[UIView alloc] initWithFrame:frame];
	
	/* re-register user agent with our hash, which should only affect this UIWebView */
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"UserAgent": [NSString stringWithFormat:@"%@/%lu", [appDelegate defaultUserAgent], self.hash] }];
	
	_webView = [[UIWebView alloc] initWithFrame:CGRectZero];
	_needsRefresh = FALSE;
	if (rid != nil) {
		[_webView setRestorationIdentifier:rid];
		_needsRefresh = TRUE;
	}
	[_webView setDelegate:self];
	[_webView setScalesPageToFit:YES];
	[_webView setAutoresizesSubviews:YES];
	
	[_webView.scrollView setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
	[_webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
	
	/* XXX: this may violate app store guidelines */
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(webKitprogressEstimateChanged:) name:@"WebProgressEstimateChangedNotification" object:[_webView valueForKeyPath:@"documentView.webView"]];
	
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
	[_title setFont:[UIFont boldSystemFontOfSize:16.0]];
	[_title setLineBreakMode:NSLineBreakByTruncatingTail];
	[_title setTextAlignment:NSTextAlignmentCenter];
	[_title setText:@"New Tab"];
	
	_closer = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 0)];
	[_closer setTextColor:[UIColor whiteColor]];
	[_closer setFont:[UIFont systemFontOfSize:24.0]];
	[_closer setText:[NSString stringWithFormat:@"%C", 0x2715]];

	[_viewHolder addSubview:_titleHolder];
	[_viewHolder addSubview:_title];
	[_viewHolder addSubview:_closer];
	[_viewHolder addSubview:_webView];
	
	/* setup shadow that will be shown when zooming out */
	[[_viewHolder layer] setMasksToBounds:NO];
	[[_viewHolder layer] setShadowOffset:CGSizeMake(0, 0)];
	[[_viewHolder layer] setShadowRadius:8];
	[[_viewHolder layer] setShadowOpacity:0];
	
	_progress = @0.0;
	
	[self updateFrame:frame];

	[self zoomNormal];
	
	[self setSecureMode:WebViewTabSecureModeInsecure];
	[self setApplicableHTTPSEverywhereRules:[[NSMutableDictionary alloc] initWithCapacity:6]];
	
	for (UIView *_view in _webView.subviews) {
		for (UIGestureRecognizer *recognizer in _view.gestureRecognizers) {
			[recognizer addTarget:self action:@selector(webViewTouched:)];
		}
		for (UIView *_sview in _view.subviews) {
			for (UIGestureRecognizer *recognizer in _sview.gestureRecognizers) {
				[recognizer addTarget:self action:@selector(webViewTouched:)];
			}
		}
	}
	
	/* this doubles as a way to force the webview to initialize itself, otherwise the UA doesn't seem to set right before refreshing a previous restoration state */
	NSString *ua = [_webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
	NSArray *uap = [ua componentsSeparatedByString:@"/"];
	NSString *wvthash = uap[uap.count - 1];
	if (![[NSString stringWithFormat:@"%lu", [self hash]] isEqualToString:wvthash])
		abort();
	
	return self;
}

- (void)close
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"WebProgressEstimateChangedNotification" object:[_webView valueForKeyPath:@"documentView.webView"]];
	[_webView stopLoading];
	_webView = nil;
}

/* XXX: this may violate app store guidelines */
- (void)webKitprogressEstimateChanged:(NSNotification*)notification
{
	[self setProgress:[NSNumber numberWithFloat:[[notification object] estimatedProgress]]];
}

- (void)webViewTouched:(UIEvent *)event
{
	[[appDelegate webViewController] webViewTouched];
}

- (void)updateFrame:(CGRect)frame
{
	[self.viewHolder setFrame:frame];
	[self.webView setFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
	[self.titleHolder setFrame:CGRectMake(0, -26, frame.size.width, 32)];
	[self.closer setFrame:CGRectMake(3, -22, 18, 18)];
	[self.title setFrame:CGRectMake(22, -20, frame.size.width - 22 - 22, 16)];
}

- (void)prepareForNewURL:(NSURL *)URL
{
	[self setSecureMode:WebViewTabSecureModeInsecure];
	[[self applicableHTTPSEverywhereRules] removeAllObjects];
	[self setUrl:URL];
}

- (void)loadURL:(NSURL *)u
{
	[self loadURL:u withForce:NO];
}

- (void)loadURL:(NSURL *)u withForce:(BOOL)force
{
	[self.webView stopLoading];
	[self prepareForNewURL:u];
	
	NSMutableURLRequest *ur = [NSMutableURLRequest requestWithURL:u];
	if (force)
		[ur setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];

	[self.webView loadRequest:ur];
}

/* this will only fire for top-level requests, not page elements */
- (BOOL)webView:(UIWebView *)__webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	if (![[[request URL] scheme] isEqualToString:@"endlessipc"]) {
		[self prepareForNewURL:[request mainDocumentURL]];

		return YES;
	}
	
	/* endlessipc://fakeWindow.open/somerandomid?http... */
	
	NSString *action = [[request URL] host];
	
	NSString *param, *param2;
	if ([[[request URL] pathComponents] count] >= 2)
		param = [[request URL] pathComponents][1];
	if ([[[request URL] pathComponents] count] >= 3)
		param2 = [[request URL] pathComponents][2];
	
	NSString *value = [[[[request URL] query] stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
	
	if ([action isEqualToString:@"console.log"]) {
		NSString *json = [[[[request URL] query] stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		NSLog(@"[Tab %@] [console.%@] %@", [self tabIndex], param, json);
		/* no callback needed */
		return NO;
	}
	
#ifdef TRACE
	NSLog(@"[Javascript IPC]: [%@] [%@] [%@] [%@]", action, param, param2, value);
#endif
	
	if ([action isEqualToString:@"noop"]) {
		[self webView:__webView callbackWith:@""];
	}
	else if ([action isEqualToString:@"window.open"]) {
		/* only allow windows to be opened from mouse/touch events, like a normal browser's popup blocker */
		if (navigationType == UIWebViewNavigationTypeLinkClicked) {
			WebViewTab *newtab = [[appDelegate webViewController] addNewTabForURL:nil];
			newtab.randID = param;
			newtab.openedByTabHash = [NSNumber numberWithLong:self.hash];
			
			[self webView:__webView callbackWith:[NSString stringWithFormat:@"__endless.openedTabs[\"%@\"].opened = true;", param]];
		}
		else {
			/* TODO: show a "popup blocked" warning? */
			NSLog(@"[Tab %@] blocked non-touch window.open() (nav type %lu)", self.tabIndex, navigationType);
			
			[self webView:__webView callbackWith:[NSString stringWithFormat:@"__endless.openedTabs[\"%@\"].opened = false;", param]];
		}
	}
	else if ([action isEqualToString:@"window.close"]) {
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Confirm" message:@"Allow this page to close its tab?" preferredStyle:UIAlertControllerStyleAlert];
		
		UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[[appDelegate webViewController] removeTab:[self tabIndex]];
		}];
		
		UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
		[alertController addAction:cancelAction];
		[alertController addAction:okAction];
		
		[[appDelegate webViewController] presentViewController:alertController animated:YES completion:nil];
		
		[self webView:__webView callbackWith:@""];
	}
	else if ([action hasPrefix:@"fakeWindow."]) {
		WebViewTab *wvt = [[self class] openedWebViewTabByRandID:param];
		
		if (wvt == nil) {
			[self webView:__webView callbackWith:[NSString stringWithFormat:@"delete __endless.openedTabs[\"%@\"];", [param stringEscapedForJavasacript]]];
		}
		/* setters, just write into target webview */
		else if ([action isEqualToString:@"fakeWindow.setName"]) {
			[[wvt webView] stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.name = \"%@\";", [value stringEscapedForJavasacript]]];
			[self webView:__webView callbackWith:@""];
		}
		else if ([action isEqualToString:@"fakeWindow.setLocation"]) {
			[[wvt webView] stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.location = \"%@\";", [value stringEscapedForJavasacript]]];
			[self webView:__webView callbackWith:@""];
		}
		else if ([action isEqualToString:@"fakeWindow.setLocationParam"]) {
			/* TODO: whitelist param since we're sending it raw */
			[[wvt webView] stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.location.%@ = \"%@\";", param2, [value stringEscapedForJavasacript]]];
			[self webView:__webView callbackWith:@""];
		}
		
		/* getters, pull from target webview and write back to caller internal parameters (not setters) */
		else if ([action isEqualToString:@"fakeWindow.getName"]) {
			NSString *name = [[wvt webView] stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.name;"]];
			[self webView:__webView callbackWith:[NSString stringWithFormat:@"__endless.openedTabs[\"%@\"]._name = \"%@\";", [param stringEscapedForJavasacript], [name stringEscapedForJavasacript]]];
		}
		else if ([action isEqualToString:@"fakeWindow.getLocation"]) {
			NSString *loc = [[wvt webView] stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"JSON.stringify(window.location);"]];
			/* don't encode loc, it's (hopefully a safe) hash */
			[self webView:__webView callbackWith:[NSString stringWithFormat:@"__endless.openedTabs[\"%@\"]._location = new __endless.FakeLocation(%@)", [param stringEscapedForJavasacript], loc]];
		}
		
		/* actions */
		else if ([action isEqualToString:@"fakeWindow.close"]) {
			[[appDelegate webViewController] removeTab:[wvt tabIndex]];
			[self webView:__webView callbackWith:@""];
		}
	}
	
	return NO;
}

- (void)webViewDidStartLoad:(UIWebView *)__webView
{
	/* reset and then let WebViewController animate to our actual progress */
	[self setProgress:@0.0];
	[self setProgress:@0.1];

	if (self.url == nil)
		self.url = [[__webView request] URL];
}

- (void)webViewDidFinishLoad:(UIWebView *)__webView
{
#ifdef TRACE
	NSLog(@"[Tab %@] finished loading page/iframe %@", self.tabIndex, [[[__webView request] URL] absoluteString]);
#endif
	[self setProgress:@1.0];
	
	[__webView stringByEvaluatingJavaScriptFromString:[[self class] javascriptToInject]];
	
	[self.title setText:[__webView stringByEvaluatingJavaScriptFromString:@"document.title"]];
	self.url = [NSURL URLWithString:[__webView stringByEvaluatingJavaScriptFromString:@"window.location.href"]];
}

- (void)webView:(UIWebView *)__webView didFailLoadWithError:(NSError *)error
{
	if (error.code != NSURLErrorCancelled) {
		UIAlertView *m = [[UIAlertView alloc] initWithTitle:@"Error" message:[error localizedDescription] delegate:self cancelButtonTitle: @"Ok" otherButtonTitles:nil];
		[m show];
	}
	
	[self webViewDidFinishLoad:__webView];
}

- (void)webView:(UIWebView *)__webView callbackWith:(NSString *)callback
{
	NSString *finalcb = [NSString stringWithFormat:@"(function() { %@; __endless.ipcDone = (new Date()).getTime(); })();", callback];

#ifdef TRACE_IPC
	NSLog(@"[Javascript IPC]: calling back with: %@", finalcb);
#endif
	
	[__webView stringByEvaluatingJavaScriptFromString:finalcb];
}

- (void)setProgress:(NSNumber *)pr
{
	_progress = pr;
	[[appDelegate webViewController] updateProgress];
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
	return ((self.webView && [self.webView canGoBack]) || self.openedByTabHash != nil);
}

- (BOOL)canGoForward
{
	return !!(self.webView && [self.webView canGoForward]);
}

- (void)goBack
{
	if ([self.webView canGoBack]) {
		[[self webView] goBack];
	}
	else if (self.openedByTabHash) {
		for (WebViewTab *wvt in [[appDelegate webViewController] webViewTabs]) {
			if ([wvt hash] == [self.openedByTabHash longValue]) {
				[[appDelegate webViewController] removeTab:self.tabIndex andFocusTab:[wvt tabIndex]];
				return;
			}
		}
		
		[[appDelegate webViewController] removeTab:self.tabIndex];
	}
}

- (void)goForward
{
	if ([[self webView] canGoForward])
		[[self webView] goForward];
}

- (void)refresh
{
	[self setNeedsRefresh:FALSE];
	[[self webView] reload];
}

- (void)forceRefresh
{
	[self loadURL:[self url] withForce:YES];
}

- (void)zoomOut
{
	[[self webView] setUserInteractionEnabled:NO];

	[_titleHolder setHidden:false];
	[_title setHidden:false];
	[_closer setHidden:false];
	[[[self viewHolder] layer] setShadowOpacity:0.3];
	[[self viewHolder] setTransform:CGAffineTransformMakeScale(ZOOM_OUT_SCALE, ZOOM_OUT_SCALE)];
}

- (void)zoomNormal
{
	[[self webView] setUserInteractionEnabled:YES];

	[_titleHolder setHidden:true];
	[_title setHidden:true];
	[_closer setHidden:true];
	[[[self viewHolder] layer] setShadowOpacity:0];
	[[self viewHolder] setTransform:CGAffineTransformMakeScale(1.0, 1.0)];
}

@end
