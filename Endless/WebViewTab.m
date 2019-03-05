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

#import "NSString+DTURLEncoding.h"
#import "VForceTouchGestureRecognizer.h"

@import WebKit;

@implementation WebViewTab {
	AppDelegate *appDelegate;
	BOOL inForceTouch;
	BOOL skipHistory;
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
	[_webView.scrollView setContentInsetAdjustmentBehavior:UIScrollViewContentInsetAdjustmentNever];
	
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
	[self.refresher setAttributedTitle:[[NSAttributedString alloc] initWithString:NSLocalizedString(@"Pull to Refresh Page", nil)]];
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

	VForceTouchGestureRecognizer *forceTouch = [[VForceTouchGestureRecognizer alloc] initWithTarget:self action:@selector(pressedMenu:)];
	[forceTouch setDelegate:self];
	[forceTouch setPercentMinimalRequest:0.4];
	inForceTouch = NO;
	[self.webView addGestureRecognizer:forceTouch];
	
	UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pressedMenu:)];
	[lpgr setDelegate:self];
	[self.webView addGestureRecognizer:lpgr];
	
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
	
	self.history = [[NSMutableArray alloc] initWithCapacity:HISTORY_SIZE];
	
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
	
	void (^block)(void) = ^{
		[self->_webView setDelegate:nil];
		[self->_webView stopLoading];
		
		for (id gr in [self->_webView gestureRecognizers])
			[self->_webView removeGestureRecognizer:gr];
		
		self->_webView = nil;
		
		[[self viewHolder] removeFromSuperview];
	};
	
	if ([NSThread isMainThread])
		block();
	else
		dispatch_sync(dispatch_get_main_queue(), ^{
			block();
		});
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
	void (^block)(void) = ^{
		[self.webView stopLoading];
		[self prepareForNewURL:[req URL]];
	
		if (force)
			[self setForcingRefresh:YES];
	
		[self.webView loadRequest:req];
	};
	
	if ([NSThread isMainThread])
		block();
	else
		dispatch_sync(dispatch_get_main_queue(), ^{
			block();
		});
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
		urls = [NSString stringWithFormat:[se objectForKey:@"search_url"], [query stringByURLEncoding]];
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
			
			[params appendString:[key stringByURLEncoding]];
			[params appendString:@"="];
			
			NSString *val = [pp objectForKey:key];
			if ([val isEqualToString:@"%@"])
				val = [query stringByURLEncoding];
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
	
	/* treat onionhttps?:// links clicked inside of web pages as normal links */
	if ([[[url scheme] lowercaseString] isEqualToString:@"onionhttp"]) {
		NSMutableURLRequest *tr = [request mutableCopy];
		[tr setURL:[NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"onionhttp" length]) withString:@"http"]]];
		[self loadRequest:tr withForce:NO];
		return NO;
	}
	else if ([[[url scheme] lowercaseString] isEqualToString:@"onionhttps"]) {
		NSMutableURLRequest *tr = [request mutableCopy];
		[tr setURL:[NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"onionhttps" length]) withString:@"https"]]];
		[self loadRequest:tr withForce:NO];
		return NO;
	}
	
	/* regular http/https urls */
	else if (![[url scheme] isEqualToString:@"endlessipc"]) {
		/* try to prevent universal links from triggering by refusing the initial request and starting a new one */
		BOOL iframe = ![[[request URL] absoluteString] isEqualToString:[[request mainDocumentURL] absoluteString]];
		
		HostSettings *hs = [HostSettings settingsOrDefaultsForHost:[url host]];
		if ([hs boolSettingOrDefault:HOST_SETTINGS_KEY_UNIVERSAL_LINK_PROTECTION]) {
			if (iframe && navigationType != UIWebViewNavigationTypeLinkClicked) {
#ifdef TRACE
				NSLog(@"[Tab %@] not doing universal link workaround for iframe %@", [self tabIndex], url);
#endif
			} else if (navigationType == UIWebViewNavigationTypeBackForward) {
#ifdef TRACE
				NSLog(@"[Tab %@] not doing universal link workaround for back/forward navigation to %@", [self tabIndex], url);
#endif
			} else if (navigationType == UIWebViewNavigationTypeFormSubmitted) {
#ifdef TRACE
				NSLog(@"[Tab %@] not doing universal link workaround for form submission to %@", [self tabIndex], url);
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
		} else {
#ifdef TRACE
			NSLog(@"[Tab %@] not doing universal link workaround for %@ due to HostSettings", [self tabIndex], url);
#endif
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
		NSLog(@"[Tab %@] [console.%@] %@", [self tabIndex], param, value);
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
			
			[self webView:__webView callbackWith:[NSString stringWithFormat:@"__endless.openedTabs[\"%@\"].opened = true;", [param stringEscapedForJavasacript]]];
		}
		else {
			/* TODO: show a "popup blocked" warning? */
			NSLog(@"[Tab %@] blocked non-touch window.open() (nav type %ldl)", self.tabIndex, (long)navigationType);
			
			[self webView:__webView callbackWith:[NSString stringWithFormat:@"__endless.openedTabs[\"%@\"].opened = false;", [param stringEscapedForJavasacript]]];
		}
	}
	else if ([action isEqualToString:@"window.close"]) {
		UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Confirm", nil) message:NSLocalizedString(@"Allow this page to close its tab?", nil) preferredStyle:UIAlertControllerStyleAlert];
		
		UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			[[self->appDelegate webViewController] removeTab:[self tabIndex]];
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
			/* must match injected.js */
			NSArray *validParams = @[ @"hash", @"hostname", @"href", @"pathname", @"port", @"protocol", @"search", @"username", @"password", @"origin" ];
			
			if (param2 != nil && [validParams containsObject:param2])
				[[wvt webView] stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"window.location.%@ = \"%@\";", param2, [value stringEscapedForJavasacript]]];
			else
				NSLog(@"[Tab %@] window.%@ not implemented", self.tabIndex, param2);
			
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
	
	/* if we're viewing just an image, scale it down to fit the screen width and color its background */
	NSString *ctype = [__webView stringByEvaluatingJavaScriptFromString:@"document.contentType"];
	if (ctype != nil && [ctype hasPrefix:@"image/"]) {
		[__webView stringByEvaluatingJavaScriptFromString:@"(function(){ document.body.style.backgroundColor = '#202020'; var i = document.getElementsByTagName('img')[0]; if (i && i.clientWidth > window.innerWidth) { var m = document.createElement('meta'); m.name='viewport'; m.content='width=device-width, initial-scale=1, maximum-scale=5'; document.getElementsByTagName('head')[0].appendChild(m); i.style.width = '100%'; } })();"];
	}
	
	[self.title setText:docTitle];
	self.url = [NSURL URLWithString:finalURL];
	
	if (!skipHistory) {
		while (self.history.count > HISTORY_SIZE)
			[self.history removeObjectAtIndex:0];
		
		if (self.history.count == 0 || ![[[self.history lastObject] objectForKey:@"url"] isEqualToString:finalURL])
			[self.history addObject:@{ @"url" : finalURL, @"title" : docTitle }];
	}
	
	skipHistory = NO;
}

- (void)webView:(UIWebView *)__webView didFailLoadWithError:(NSError *)error
{
	BOOL isTLSError = false;
	
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
			msg = NSLocalizedString(@"TLS protocol error", nil);
			isTLSError = true;
			break;
		case errSSLNegotiation: /* -9801 */
			msg = NSLocalizedString(@"TLS handshake failed", nil);
			isTLSError = true;
			break;
		case errSSLXCertChainInvalid: /* -9807 */
			msg = NSLocalizedString(@"TLS certificate chain verification error (self-signed certificate?)", nil);
			isTLSError = true;
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
	[uiac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];

    // "Connection refused", most possibly created, because Tor's sockets were closed by iOS
    // during app sleep. This is non-recoverable. We show a different message, here.
    if (error.code == 61)
    {
        [uiac setTitle:NSLocalizedString(@"Tor connection failure", nil)];
        [uiac setMessage:NSLocalizedString(@"__CONNECTION_FAILURE_DESCRIPTION__", nil)];

        [uiac addAction:[UIAlertAction
                         actionWithTitle:NSLocalizedString(@"Quit App", nil)
                         style:UIAlertActionStyleDestructive
                         handler:^(UIAlertAction* action){
                             UIApplication *application = [UIApplication sharedApplication];
                             [application performSelector:@selector(suspend)];

                             AppDelegate *appDelegate = (AppDelegate *)[application delegate];
                             [appDelegate applicationDidEnterBackground:application];
                             [appDelegate applicationWillTerminate:application];

                             [NSThread sleepForTimeInterval:2];
                             exit(0);
                         }]];
    }

    if (u != nil && isTLSError && [[NSUserDefaults standardUserDefaults] boolForKey:@"allow_tls_error_ignore"]) {
		[uiac addAction:[UIAlertAction
						 actionWithTitle:NSLocalizedString(@"Ignore for this host", nil)
						 style:UIAlertActionStyleDestructive
						 handler:^(UIAlertAction * _Nonnull action) {

			/*
			 * self.url will hold the URL of the UIWebView which is the last *successful* request.
			 * We need the URL of the *failed* request, which should be in `u`.
			 * (From `error`'s `userInfo` dictionary.
			 */
			NSURL *url = [[NSURL alloc] initWithString:u];
			if (url != nil) {
				HostSettings *hs = [HostSettings forHost:url.host];

				if (hs == nil) {
					hs = [[HostSettings alloc] initForHost:url.host withDict:nil];
				}

				[hs setSetting:HOST_SETTINGS_KEY_IGNORE_TLS_ERRORS toValue:HOST_SETTINGS_VALUE_YES];

				[hs save];
				[HostSettings persist];

				// Retry the failed request.
				[self loadURL:url];
			}
		}]];
	}

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

- (void)pressedMenu:(UIGestureRecognizer *)event
{
	UIAlertController *alertController;
	NSString *href, *img, *alt;
	
	if ([event isKindOfClass:[VForceTouchGestureRecognizer class]]) {
		if ([event state] == UIGestureRecognizerStateBegan) {
			inForceTouch = YES;
		} else if ([event state] == UIGestureRecognizerStateChanged) {
			inForceTouch = YES;
			return;
		} else {
			inForceTouch = NO;
			return;
		}
	} else if (inForceTouch || [event state] != UIGestureRecognizerStateBegan) {
		return;
	}

#ifdef TRACE
	NSLog(@"[Tab %@] %@ gesture recognized (%@)", [event class], self.tabIndex, event);
#endif
	
	NSArray *elements = [self elementsAtLocationFromGestureRecognizer:event];
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
		event.enabled = false;
		event.enabled = true;
		return;
	}
	
	if (inForceTouch) {
		/* taptic feedback */
		UINotificationFeedbackGenerator *uinfg = [[UINotificationFeedbackGenerator alloc] init];
		[uinfg prepare];
		[uinfg notificationOccurred:UINotificationFeedbackTypeSuccess];
		
		NSURL *u;
		if (href)
			u = [NSURL URLWithString:href];
		else if (img)
			u = [NSURL URLWithString:img];

		if (u) {
			WebViewTab *newtab = [[appDelegate webViewController] addNewTabForURL:u forRestoration:NO withAnimation:WebViewTabAnimationQuick withCompletionBlock:nil];
			newtab.openedByTabHash = [NSNumber numberWithLong:self.hash];
		}
		
		return;
	}
	
	alertController = [UIAlertController alertControllerWithTitle:href message:alt preferredStyle:UIAlertControllerStyleActionSheet];
	
	UIAlertAction *openAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[self loadURL:[NSURL URLWithString:href]];
	}];
	
	UIAlertAction *openNewTabAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open in a New Tab", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		WebViewTab *newtab = [[self->appDelegate webViewController] addNewTabForURL:[NSURL URLWithString:href]];
		newtab.openedByTabHash = [NSNumber numberWithLong:self.hash];
	}];
	
	UIAlertAction *openSafariAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Open in Safari", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:href] options:@{} completionHandler:nil];
	}];

	UIAlertAction *saveImageAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Save Image", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		NSURL *imgurl = [NSURL URLWithString:img];
		[URLInterceptor temporarilyAllow:imgurl];
		NSData *imgdata = [NSData dataWithContentsOfURL:imgurl];
		if (imgdata) {
			UIImage *i = [UIImage imageWithData:imgdata];
			UIImageWriteToSavedPhotosAlbum(i, self, nil, nil);
		}
		else {
			UIAlertController *uiac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Error", nil) message:[NSString stringWithFormat:NSLocalizedString(@"An error occurred downloading image %@", nil), img] preferredStyle:UIAlertControllerStyleAlert];
			[uiac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleDefault handler:nil]];
			[[self->appDelegate webViewController] presentViewController:uiac animated:YES completion:nil];
		}
	}];
	
	UIAlertAction *copyURLAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Copy URL", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
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
		popover.sourceView = [event view];
		CGPoint loc = [event locationInView:[event view]];
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
		skipHistory = YES;
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
	if ([[self webView] canGoForward]) {
		skipHistory = YES;
		[[self webView] goForward];
	}
}

- (void)refresh
{
	[self setNeedsRefresh:FALSE];
	skipHistory = YES;
	[[self webView] reload];
}

- (void)forceRefresh
{
	skipHistory = YES;
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

/* UIActivityItemSource for URL sharing */
- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
	return [self url];
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(UIActivityType)activityType
{
	return [self url];
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(UIActivityType)activityType
{
	return [[self title] text];
}

@end
