/*
 * Endless
 * Copyright (c) 2014-2017 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "URLInterceptor.h"
#import "WebViewTab.h"

#import "NSString+JavascriptEscape.h"
#import "UIResponder+FirstResponder.h"

@import WebKit;

@implementation WebViewTab {
	AppDelegate *appDelegate;
}

+ (WebViewTab *)openedWebViewTabByRandID:(NSString *)randID
{
	for (WebViewTab *wvt in [[(AppDelegate *)[[UIApplication sharedApplication] delegate] webViewController] webViewTabs]) {
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
	[[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"UserAgent": [NSString stringWithFormat:@"%@/%lu", [appDelegate defaultUserAgent], (unsigned long)self.hash] }];
	
	_webView = [[UIWebView alloc] initWithFrame:CGRectZero];
	_needsRefresh = FALSE;
	if (rid != nil) {
		[_webView setRestorationIdentifier:rid];
		_needsRefresh = TRUE;
	}
	[_webView setDelegate:self];
	[_webView setScalesPageToFit:YES];
	[_webView setAutoresizesSubviews:YES];
	[_webView setAllowsInlineMediaPlayback:YES];
	
	[_webView.scrollView setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
	[_webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
	[_webView.scrollView setDecelerationRate:UIScrollViewDecelerationRateNormal];
	
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
	
	self.refresher = [[UIRefreshControl alloc] init];
	[self.refresher setAttributedTitle:[[NSAttributedString alloc] initWithString:@"Pull to Refresh Page"]];
	[self.refresher addTarget:self action:@selector(forceRefreshFromRefresher) forControlEvents:UIControlEventValueChanged];
	[self.webView.scrollView addSubview:self.refresher];
	
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
	[self setApplicableHTTPSEverywhereRules:[[NSMutableDictionary alloc] init]];
	[self setApplicableURLBlockerTargets:[[NSMutableDictionary alloc] init]];

	UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressMenu:)];
	[lpgr setDelegate:self];
	[_webView addGestureRecognizer:lpgr];

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
	if (![[NSString stringWithFormat:@"%lu", (unsigned long)[self hash]] isEqualToString:wvthash])
		abort();
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"WebProgressEstimateChangedNotification" object:[_webView valueForKeyPath:@"documentView.webView"]];
	[_webView setDelegate:nil];
	[_webView stopLoading];
	
	for (id gr in [_webView gestureRecognizers])
		[_webView removeGestureRecognizer:gr];
	
	_webView = nil;
	
	[[self viewHolder] removeFromSuperview];
}

/* for long press gesture recognizer to work properly */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
	if (![gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]])
		return NO;
	
	if ([gestureRecognizer state] != UIGestureRecognizerStateBegan)
		return YES;

	BOOL haveLinkOrImage = NO;

	NSArray *elements = [self elementsAtLocationFromGestureRecognizer:gestureRecognizer];
	for (NSDictionary *element in elements) {
		NSString *k = [element allKeys][0];
		
		if ([k isEqualToString:@"a"] || [k isEqualToString:@"img"]) {
			haveLinkOrImage = YES;
			break;
		}
	}
	
	if (haveLinkOrImage) {
		/* this is enough to cancel the touch when the long press gesture fires, so that the link being held down doesn't activate as a click once the finger is let up */
		if ([otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
			otherGestureRecognizer.enabled = NO;
			otherGestureRecognizer.enabled = YES;
		}
		
		return YES;
	}
	
	return NO;
}

- (void)webKitprogressEstimateChanged:(NSNotification*)notification
{
	[self setProgress:[NSNumber numberWithFloat:[[notification object] estimatedProgress]]];
}

- (void)updateFrame:(CGRect)frame
{
	[self.viewHolder setFrame:frame];
	[self.webView setFrame:CGRectMake(0, 0, frame.size.width, frame.size.height)];
	
	if ([[appDelegate webViewController] toolbarOnBottom]) {
		[self.titleHolder setFrame:CGRectMake(0, frame.size.height, frame.size.width, 32)];
		[self.closer setFrame:CGRectMake(3, frame.size.height + 8, 18, 18)];
		[self.title setFrame:CGRectMake(22, frame.size.height + 8, frame.size.width - 22 - 22, 18)];
	}
	else {
		[self.titleHolder setFrame:CGRectMake(0, -26, frame.size.width, 32)];
		[self.closer setFrame:CGRectMake(3, -22, 18, 18)];
		[self.title setFrame:CGRectMake(22, -22, frame.size.width - 22 - 22, 18)];
	}
}

- (void)prepareForNewURL:(NSURL *)URL
{
	[[self applicableHTTPSEverywhereRules] removeAllObjects];
	[[self applicableURLBlockerTargets] removeAllObjects];
	[self setSSLCertificate:nil];
	[self setUrl:URL];
}

- (void)loadURL:(NSURL *)u
{
	[self loadURL:u withForce:NO];
}

- (void)loadURL:(NSURL *)u withForce:(BOOL)force
{
	[self loadRequest:[NSURLRequest requestWithURL:u] withForce:force];
}

- (void)loadRequest:(NSURLRequest *)req withForce:(BOOL)force
{
	[self.webView stopLoading];
	[self prepareForNewURL:[req URL]];
	
	if (force)
		[self setForcingRefresh:YES];
 
	[self.webView loadRequest:req];
}

- (void)searchFor:(NSString *)query
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *se = [[appDelegate searchEngines] objectForKey:[userDefaults stringForKey:@"search_engine"]];
	
	if (se == nil)
		/* just pick the first search engine */
		se = [[appDelegate searchEngines] objectForKey:[[[appDelegate searchEngines] allKeys] firstObject]];
	
	NSDictionary *pp = [se objectForKey:@"post_params"];
	NSString *urls;
	if (pp == nil)
		urls = [[NSString stringWithFormat:[se objectForKey:@"search_url"], query] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
	else
		urls = [se objectForKey:@"search_url"];
	
	NSURL *url = [NSURL URLWithString:urls];
	if (pp == nil) {
#ifdef TRACE
		NSLog(@"[Tab %@] searching via %@", self.tabIndex, url);
#endif
		[self loadURL:url];
	}
	else {
		/* need to send this as a POST, so build our key val pairs */
		NSMutableString *params = [NSMutableString stringWithFormat:@""];
		for (NSString *key in [pp allKeys]) {
			if (![params isEqualToString:@""])
				[params appendString:@"&"];
			
			[params appendString:[key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
			[params appendString:@"="];
			
			NSString *val = [pp objectForKey:key];
			if ([val isEqualToString:@"%@"])
				val = [query stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
			[params appendString:val];
		}
		
		[self.webView stopLoading];
		[self prepareForNewURL:url];
		
#ifdef TRACE
		NSLog(@"[Tab %@] searching via POST to %@ (with params %@)", self.tabIndex, url, params);
#endif

		NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody:[params dataUsingEncoding:NSUTF8StringEncoding]];
		[self.webView loadRequest:request];
	}
}

/* this will only fire for top-level requests (and iframes), not page elements */
- (BOOL)webView:(UIWebView *)__webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
	NSURL *url = [request URL];
	
	/* treat endlesshttps?:// links clicked inside of web pages as normal links */
	if ([[[url scheme] lowercaseString] isEqualToString:@"endlesshttp"]) {
		NSMutableURLRequest *tr = [request mutableCopy];
		[tr setURL:[NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"endlesshttp" length]) withString:@"http"]]];
		[self loadRequest:tr withForce:NO];
		return NO;
	}
	else if ([[[url scheme] lowercaseString] isEqualToString:@"endlesshttps"]) {
		NSMutableURLRequest *tr = [request mutableCopy];
		[tr setURL:[NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"endlesshttps" length]) withString:@"https"]]];
		[self loadRequest:tr withForce:NO];
		return NO;
	}
	
	/* regular http/https urls */
	else if (![[url scheme] isEqualToString:@"endlessipc"]) {
		/* try to prevent universal links from triggering by refusing the initial request and starting a new one */
		BOOL iframe = ![[[request URL] absoluteString] isEqualToString:[[request mainDocumentURL] absoluteString]];
		if (iframe) {
#ifdef TRACE
			NSLog(@"[Tab %@] not doing universal link workaround for iframe %@", [self tabIndex], url);
#endif
		} else if (navigationType == UIWebViewNavigationTypeBackForward) {
#ifdef TRACE
			NSLog(@"[Tab %@] not doing universal link workaround for back/forward navigation to %@", [self tabIndex], url);
#endif
		} else if ([[[url scheme] lowercaseString] hasPrefix:@"http"] && ![NSURLProtocol propertyForKey:UNIVERSAL_LINKS_WORKAROUND_KEY inRequest:request]) {
			NSMutableURLRequest *tr = [request mutableCopy];
			[NSURLProtocol setProperty:@YES forKey:UNIVERSAL_LINKS_WORKAROUND_KEY inRequest:tr];
#ifdef TRACE
			NSLog(@"[Tab %@] doing universal link workaround for %@", [self tabIndex], url);
#endif
			[self loadRequest:tr withForce:NO];
			return NO;
		}
		
		if (!iframe)
			[self prepareForNewURL:[request mainDocumentURL]];

		return YES;
	}
	
	/* endlessipc://fakeWindow.open/somerandomid?http... */
	
	NSString *action = [url host];
	
	NSString *param, *param2;
	if ([[[request URL] pathComponents] count] >= 2)
		param = [url pathComponents][1];
	if ([[[request URL] pathComponents] count] >= 3)
		param2 = [url pathComponents][2];
	
	NSString *value = [[[url query] stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByRemovingPercentEncoding];
	
	if ([action isEqualToString:@"console.log"]) {
		NSString *json = [[[url query] stringByReplacingOccurrencesOfString:@"+" withString:@" "] stringByRemovingPercentEncoding];
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
			NSLog(@"[Tab %@] blocked non-touch window.open() (nav type %ldl)", self.tabIndex, (long)navigationType);
			
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
	NSLog(@"[Tab %@] finished loading page/iframe %@, security level is %lu", self.tabIndex, [[[__webView request] URL] absoluteString], self.secureMode);
#endif
	[self setProgress:@1.0];
	[self setForcingRefresh:NO];

	NSString *docTitle = [__webView stringByEvaluatingJavaScriptFromString:@"document.title"];
	NSString *finalURL = [__webView stringByEvaluatingJavaScriptFromString:@"window.location.href"];
	
	/* if we have javascript blocked, these will be empty */
	if (finalURL == nil || [finalURL isEqualToString:@""])
		finalURL = [[[__webView request] mainDocumentURL] absoluteString];
	if (docTitle == nil || [docTitle isEqualToString:@""])
		docTitle = finalURL;
	
	[self.title setText:docTitle];
	self.url = [NSURL URLWithString:finalURL];
}

- (void)webView:(UIWebView *)__webView didFailLoadWithError:(NSError *)error
{
	self.url = __webView.request.URL;
	[self setProgress:@0];
	
	if ([[error domain] isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled)
		return;
	
	/* "The operation couldn't be completed. (Cocoa error 3072.)" - useless */
	if ([[error domain] isEqualToString:NSCocoaErrorDomain] && error.code == NSUserCancelledError)
		return;
	
	/* "Frame load interrupted" - not very helpful */
	if ([[error domain] isEqualToString:@"WebKitErrorDomain"] && error.code == 102)
		return;

	NSString *msg = [error localizedDescription];
	
	/* https://opensource.apple.com/source/libsecurity_ssl/libsecurity_ssl-36800/lib/SecureTransport.h */
	if ([[error domain] isEqualToString:NSOSStatusErrorDomain]) {
		switch (error.code) {
		case errSSLProtocol: /* -9800 */
			msg = @"SSL protocol error";
			break;
		case errSSLNegotiation: /* -9801 */
			msg = @"SSL handshake failed";
			break;
		case errSSLXCertChainInvalid: /* -9807 */
			msg = @"SSL certificate chain verification error (self-signed certificate?)";
			break;
		}
	}

	NSString *u;
	if ((u = [[error userInfo] objectForKey:@"NSErrorFailingURLStringKey"]) != nil)
		msg = [NSString stringWithFormat:@"%@\n\n%@", msg, u];
	
	if ([error userInfo] != nil) {
		NSNumber *ok = [[error userInfo] objectForKey:ORIGIN_KEY];
		if (ok != nil && [ok boolValue] == NO) {
#ifdef TRACE
			NSLog(@"[Tab %@] not showing dialog for non-origin error: %@ (%@)", self.tabIndex, msg, error);
#endif
			[self webViewDidFinishLoad:__webView];
			return;
		}
	}

#ifdef TRACE
	NSLog(@"[Tab %@] showing error dialog: %@ (%@)", self.tabIndex, msg, error);
#endif

	UIAlertController *uiac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:msg preferredStyle:UIAlertControllerStyleAlert];
	[uiac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", nil) style:UIAlertActionStyleDefault handler:nil]];
	[[appDelegate webViewController] presentViewController:uiac animated:YES completion:nil];
	
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

- (void)setSSLCertificate:(SSLCertificate *)SSLCertificate
{
	_SSLCertificate = SSLCertificate;
	
	if (_SSLCertificate == nil) {
#ifdef TRACE
		NSLog(@"[Tab %@] setting securemode to insecure", self.tabIndex);
#endif
		[self setSecureMode:WebViewTabSecureModeInsecure];
	}
	else if ([[self SSLCertificate] isEV]) {
#ifdef TRACE
		NSLog(@"[Tab %@] setting securemode to ev", self.tabIndex);
#endif
		[self setSecureMode:WebViewTabSecureModeSecureEV];
	}
	else {
#ifdef TRACE
		NSLog(@"[Tab %@] setting securemode to secure", self.tabIndex);
#endif
		[self setSecureMode:WebViewTabSecureModeSecure];
	}
}

- (void)setProgress:(NSNumber *)pr
{
	_progress = pr;
	[[appDelegate webViewController] updateProgress];
}

- (void)swipeRightAction:(UISwipeGestureRecognizer *)gesture
{
	[self goBack];
}

- (void)swipeLeftAction:(UISwipeGestureRecognizer *)gesture
{
	[self goForward];
}

- (void)webViewTouched:(UIEvent *)event
{
	[[appDelegate webViewController] webViewTouched];
}

- (void)longPressMenu:(UILongPressGestureRecognizer *)sender {
	UIAlertController *alertController;
	NSString *href, *img, *alt;
	
	if (sender.state != UIGestureRecognizerStateBegan)
		return;
	
#ifdef TRACE
	NSLog(@"[Tab %@] long-press gesture recognized", self.tabIndex);
#endif
	
	NSArray *elements = [self elementsAtLocationFromGestureRecognizer:sender];
	for (NSDictionary *element in elements) {
		NSString *k = [element allKeys][0];
		NSDictionary *attrs = [element objectForKey:k];
		
		if ([k isEqualToString:@"a"]) {
			href = [attrs objectForKey:@"href"];
			
			/* only use if image alt is blank */
			if (!alt || [alt isEqualToString:@""])
				alt = [attrs objectForKey:@"title"];
		}
		else if ([k isEqualToString:@"img"]) {
			img = [attrs objectForKey:@"src"];
			
			NSString *t = [attrs objectForKey:@"title"];
			if (t && ![t isEqualToString:@""])
				alt = t;
			else
				alt = [attrs objectForKey:@"alt"];
		}
	}
	
#ifdef TRACE
	NSLog(@"[Tab %@] context menu href:%@, img:%@, alt:%@", self.tabIndex, href, img, alt);
#endif
	
	if (!(href || img)) {
		sender.enabled = false;
		sender.enabled = true;
		return;
	}
	
	alertController = [UIAlertController alertControllerWithTitle:href message:alt preferredStyle:UIAlertControllerStyleActionSheet];
	
	UIAlertAction *openAction = [UIAlertAction actionWithTitle:@"Open" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[self loadURL:[NSURL URLWithString:href]];
	}];
	
	UIAlertAction *openNewTabAction = [UIAlertAction actionWithTitle:@"Open in a New Tab" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		WebViewTab *newtab = [[appDelegate webViewController] addNewTabForURL:[NSURL URLWithString:href]];
		newtab.openedByTabHash = [NSNumber numberWithLong:self.hash];
	}];
	
	UIAlertAction *openSafariAction = [UIAlertAction actionWithTitle:@"Open in Safari" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:href] options:@{} completionHandler:nil];
	}];

	UIAlertAction *saveImageAction = [UIAlertAction actionWithTitle:@"Save Image" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		NSURL *imgurl = [NSURL URLWithString:img];
		[URLInterceptor temporarilyAllow:imgurl];
		NSData *imgdata = [NSData dataWithContentsOfURL:imgurl];
		if (imgdata) {
			UIImage *i = [UIImage imageWithData:imgdata];
			UIImageWriteToSavedPhotosAlbum(i, self, nil, nil);
		}
		else {
			UIAlertController *uiac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:[NSString stringWithFormat:@"An error occurred downloading image %@", img] preferredStyle:UIAlertControllerStyleAlert];
			[uiac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Ok", nil) style:UIAlertActionStyleDefault handler:nil]];
			[[appDelegate webViewController] presentViewController:uiac animated:YES completion:nil];
		}
	}];
	
	UIAlertAction *copyURLAction = [UIAlertAction actionWithTitle:@"Copy URL" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[UIPasteboard generalPasteboard] setString:(href ? href : img)];
	}];
	
	if (href) {
		[alertController addAction:openAction];
		[alertController addAction:openNewTabAction];
		[alertController addAction:openSafariAction];
	}
	
	if (img)
		[alertController addAction:saveImageAction];
	
	[alertController addAction:copyURLAction];
	
	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel") style:UIAlertActionStyleCancel handler:nil];
	[alertController addAction:cancelAction];
	
	UIPopoverPresentationController *popover = [alertController popoverPresentationController];
	if (popover) {
		popover.sourceView = [sender view];
		CGPoint loc = [sender locationInView:[sender view]];
		/* offset for width of the finger */
		popover.sourceRect = CGRectMake(loc.x + 35, loc.y, 1, 1);
		popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
	}
	
	[[appDelegate webViewController] presentViewController:alertController animated:YES completion:nil];
}

- (BOOL)canGoBack
{
	return (self.openedByTabHash != nil || (self.webView && [self.webView canGoBack]));
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

- (void)forceRefreshFromRefresher
{
	[self forceRefresh];
	
	/* delay just so it confirms to the user that something happened */
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
		[self.refresher endRefreshing];
	});
}

- (void)zoomOut
{
	[[self webView] setUserInteractionEnabled:NO];

	[_titleHolder setHidden:false];
	[_title setHidden:false];
	[_closer setHidden:false];
	[[[self viewHolder] layer] setShadowOpacity:0.3];
	
	BOOL rotated = (self.viewHolder.frame.size.width > self.viewHolder.frame.size.height);
	[[self viewHolder] setTransform:CGAffineTransformMakeScale(rotated ? ZOOM_OUT_SCALE_ROTATED : ZOOM_OUT_SCALE, rotated ? ZOOM_OUT_SCALE_ROTATED : ZOOM_OUT_SCALE)];
}

- (void)zoomNormal
{
	[[self webView] setUserInteractionEnabled:YES];

	[_titleHolder setHidden:true];
	[_title setHidden:true];
	[_closer setHidden:true];
	[[[self viewHolder] layer] setShadowOpacity:0];
	[[self viewHolder] setTransform:CGAffineTransformIdentity];
}

- (NSArray *)elementsAtLocationFromGestureRecognizer:(UIGestureRecognizer *)uigr
{
	CGPoint tap = [uigr locationInView:[self webView]];
	tap.y -= [[[self webView] scrollView] contentInset].top;
	
	/* translate tap coordinates from view to scale of page */
	CGSize windowSize = CGSizeMake(
				       [[[self webView] stringByEvaluatingJavaScriptFromString:@"window.innerWidth"] intValue],
				       [[[self webView] stringByEvaluatingJavaScriptFromString:@"window.innerHeight"] intValue]
				       );
	CGSize viewSize = [[self webView] frame].size;
	float ratio = windowSize.width / viewSize.width;
	CGPoint tapOnPage = CGPointMake(tap.x * ratio, tap.y * ratio);
	
	/* now find if there are usable elements at those coordinates and extract their attributes */
	NSString *json = [[self webView] stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"JSON.stringify(__endless.elementsAtPoint(%li, %li));", (long)tapOnPage.x, (long)tapOnPage.y]];
	if (json == nil) {
		NSLog(@"[Tab %@] didn't get any JSON back from __endless.elementsAtPoint", self.tabIndex);
		return @[];
	}
	
	return [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
}

- (void)handleKeyCommand:(UIKeyCommand *)keyCommand
{
	BOOL ctrlKey = NO;
	BOOL shiftKey = NO;
	BOOL altKey = NO;
	BOOL metaKey = NO;
	
	int keycode = 0;
	int keypress_keycode = 0;

	NSString *keyAction = nil;
	
	if ([keyCommand modifierFlags] & UIKeyModifierShift)
		shiftKey = YES;
	if ([keyCommand modifierFlags] & UIKeyModifierControl)
		ctrlKey = YES;
	if ([keyCommand modifierFlags] & UIKeyModifierAlternate)
		altKey = YES;
	if ([keyCommand modifierFlags] & UIKeyModifierCommand)
		metaKey = YES;
	
	for (int i = 0; i < sizeof(keyboard_map); i++) {
		struct keyboard_map_entry kme = keyboard_map[i];
		
		if ([[keyCommand input] isEqualToString:@(kme.input)]) {
			keycode = kme.keycode;
			
			if (shiftKey)
				keypress_keycode = kme.shift_keycode;
			else
				keypress_keycode = kme.keypress_keycode;
			
			break;
		}
	}
	
	if (!keycode) {
		NSLog(@"[Tab %@] unknown hardware keyboard input: \"%@\"", self.tabIndex, [keyCommand input]);
		return;
	}
	
	if ([[keyCommand input] isEqualToString:@" "])
		keyAction = @"__endless.smoothScroll(0, window.innerHeight * 0.75, 0, 0);";
	else if ([[keyCommand input] isEqualToString:@"UIKeyInputLeftArrow"])
		keyAction = @"__endless.smoothScroll(-75, 0, 0, 0);";
	else if ([[keyCommand input] isEqualToString:@"UIKeyInputRightArrow"])
		keyAction = @"__endless.smoothScroll(75, 0, 0, 0);";
	else if ([[keyCommand input] isEqualToString:@"UIKeyInputUpArrow"]) {
		if (metaKey)
			keyAction = @"__endless.smoothScroll(0, 0, 1, 0);";
		else
			keyAction = @"__endless.smoothScroll(0, -75, 0, 0);";
	}
	else if ([[keyCommand input] isEqualToString:@"UIKeyInputDownArrow"]) {
		if (metaKey)
			keyAction = @"__endless.smoothScroll(0, 0, 0, 1);";
		else
			keyAction = @"__endless.smoothScroll(0, 75, 0, 0);";
	}
	
	NSString *js = [NSString stringWithFormat:@"__endless.injectKey(%d, %d, %@, %@, %@, %@, %@);",
		keycode,
		keypress_keycode,
		(ctrlKey ? @"true" : @"false"),
		(altKey ? @"true" : @"false"),
		(shiftKey ? @"true" : @"false"),
		(metaKey ? @"true" : @"false"),
		(keyAction ? [NSString stringWithFormat:@"function() { %@ }", keyAction] : @"null")
	];
	
#ifdef TRACE_KEYBOARD_INPUT
	NSLog(@"[Tab %@] hardware keyboard input: \"%@\", keycode %d, keypress keycode %d, modifiers (%ld): ctrl:%@, shift:%@, alt:%@, meta:%@", self.tabIndex, [keyCommand input], keycode, keypress_keycode, (long)[keyCommand modifierFlags], ctrlKey ? @"YES" : @"NO", shiftKey ? @"YES" : @"NO", altKey ? @"YES" : @"NO", metaKey ? @"YES" : @"NO");
	NSLog(@"%@", js);
#endif
	
	[[self webView] stringByEvaluatingJavaScriptFromString:js];
}

@end
