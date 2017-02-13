/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * CKHTTP portions of this file are from Onion Browser
 * Copyright (c) 2012-2014 Mike Tigas <mike@tig.as>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "HSTSCache.h"
#import "HTTPSEverywhere.h"
#import "LocalNetworkChecker.h"
#import "SSLCertificate.h"
#import "URLBlocker.h"
#import "URLInterceptor.h"
#import "WebViewTab.h"

#import "NSData+CocoaDevUsersAdditions.h"

@implementation URLInterceptor {
	WebViewTab *wvt;
	NSString *userAgent;
}

static AppDelegate *appDelegate;
static BOOL sendDNT = true;
static NSMutableArray *tmpAllowed;

static NSString *_javascriptToInject;
+ (NSString *)javascriptToInject
{
	if (!_javascriptToInject) {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"injected" ofType:@"js"];
		_javascriptToInject = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	}
	
	return _javascriptToInject;
}

+ (void)setSendDNT:(BOOL)val
{
	sendDNT = val;
}

+ (void)temporarilyAllow:(NSURL *)url
{
	if (!tmpAllowed)
		tmpAllowed = [[NSMutableArray alloc] initWithCapacity:1];
	
	[tmpAllowed addObject:url];
}

+ (BOOL)isURLTemporarilyAllowed:(NSURL *)url
{
	int found = -1;
	
	for (int i = 0; i < [tmpAllowed count]; i++) {
		if ([[tmpAllowed[i] absoluteString] isEqualToString:[url absoluteString]])
			found = i;
	}
	
	if (found > -1) {
		NSLog(@"[URLInterceptor] temporarily allowing %@ from allowed list with no matching WebViewTab", url);
		[tmpAllowed removeObjectAtIndex:found];
	}
	
	return (found > -1);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	return request;
}

/*
 * Start the show: WebView will ask NSURLConnection if it can handle this request, and will eventually hit this registered handler.
 * We will intercept all requests except for data: and file:// URLs.  WebView will then call our initWithRequest.
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	if ([NSURLProtocol propertyForKey:REWRITTEN_KEY inRequest:request] != nil)
		/* already mucked with this request */
		return NO;
	
	NSString *scheme = [[[request URL] scheme] lowercaseString];
	if ([scheme isEqualToString:@"data"] || [scheme isEqualToString:@"file"])
		/* can't do anything for these URLs */
		return NO;
	
	if (appDelegate == nil)
		appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	return YES;
}

+ (NSString *)prependDirectivesIfExisting:(NSDictionary *)directives inCSPHeader:(NSString *)header
{
	/*
	 * CSP guide says apostrophe can't be in a bare string, so it should be safe to assume
	 * splitting on ; will not catch any ; inside of an apostrophe-enclosed value, since those
	 * can only be constant things like 'self', 'unsafe-inline', etc.
	 *
	 * https://www.w3.org/TR/CSP2/#source-list-parsing
	 */
 
	NSMutableDictionary *curDirectives = [[NSMutableDictionary alloc] init];
	NSArray *td = [header componentsSeparatedByString:@";"];
	for (int i = 0; i < [td count]; i++) {
		NSString *t = [(NSString *)[td objectAtIndex:i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		NSRange r = [t rangeOfString:@" "];
		if (r.length > 0) {
			NSString *dir = [[t substringToIndex:r.location] lowercaseString];
			NSString *val = [[t substringFromIndex:r.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			[curDirectives setObject:val forKey:dir];
		}
	}
	
	for (NSString *newDir in [directives allKeys]) {
		NSArray *newvals = [directives objectForKey:newDir];
		NSString *curval = [curDirectives objectForKey:newDir];
		if (curval) {
			NSString *newval = [newvals objectAtIndex:0];
			
			/*
			 * If none of the existing values for this directive have a nonce or hash,
			 * then inserting our value with a nonce will cause the directive to become
			 * strict, so "'nonce-abcd' 'self' 'unsafe-inline'" causes the browser to
			 * ignore 'self' and 'unsafe-inline', requiring that all scripts have a
			 * nonce or hash.  Since the site would probably only ever have nonce values
			 * in its <script> tags if it was in the CSP policy, only include our nonce
			 * value if the CSP policy already has them.
			 */
			if ([curval containsString:@"'nonce-"] || [curval containsString:@"'sha"])
				newval = [newvals objectAtIndex:1];
			 
			if ([curval containsString:@"'none'"]) {
				/*
				 * CSP spec says if 'none' is encountered to ignore anything else,
				 * so if 'none' is there, just replace it with newval rather than
				 * prepending.
				 */
			} else {
				if ([newval isEqualToString:@""])
					newval = curval;
				else
					newval = [NSString stringWithFormat:@"%@ %@", newval, curval];
			}
			
			[curDirectives setObject:newval forKey:newDir];
		}
	}
	
	NSMutableString *ret = [[NSMutableString alloc] init];
	for (NSString *dir in [[curDirectives allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)])
		[ret appendString:[NSString stringWithFormat:@"%@%@ %@;", ([ret length] > 0 ? @" " : @""), dir, [curDirectives objectForKey:dir]]];
	
	return [NSString stringWithString:ret];
}

/*
 * We said we can init a request for this URL, so allocate one.
 * Take this opportunity to find out what tab this request came from based on its User-Agent.
 */
- (instancetype)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client
{
	self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
	wvt = nil;
	
	/* extract tab hash from per-uiwebview user agent */
	NSString *ua = [request valueForHTTPHeaderField:@"User-Agent"];
	NSArray *uap = [ua componentsSeparatedByString:@"/"];
	NSString *wvthash = uap[uap.count - 1];
	
	/* store it for later without the hash */
	userAgent = [[uap subarrayWithRange:NSMakeRange(0, uap.count - 1)] componentsJoinedByString:@"/"];
	
	if ([NSURLProtocol propertyForKey:WVT_KEY inRequest:request])
		wvthash = [NSString stringWithFormat:@"%lu", [(NSNumber *)[NSURLProtocol propertyForKey:WVT_KEY inRequest:request] longValue]];

	if (wvthash != nil && ![wvthash isEqualToString:@""]) {
		for (WebViewTab *_wvt in [[appDelegate webViewController] webViewTabs]) {
			if ([[NSString stringWithFormat:@"%lu", (unsigned long)[_wvt hash]] isEqualToString:wvthash]) {
				wvt = _wvt;
				break;
			}
		}
	}
	
	if (wvt == nil && [[self class] isURLTemporarilyAllowed:[request URL]])
		wvt = [[[appDelegate webViewController] webViewTabs] firstObject];
	
	if (wvt == nil) {
		NSLog(@"[URLInterceptor] request for %@ with no matching WebViewTab! (main URL %@, UA hash %@)", [request URL], [request mainDocumentURL], wvthash);
		
		[client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:@{ ORIGIN_KEY: @YES }]];
		
		if (![[[[request URL] scheme] lowercaseString] isEqualToString:@"http"] && ![[[[request URL] scheme] lowercaseString] isEqualToString:@"https"]) {
			/* iOS 10 blocks canOpenURL: requests, so we just have to assume these go somewhere */
			UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Open In External App" message:[NSString stringWithFormat:@"Allow URL to be opened by external app? This may compromise your privacy.\n\n%@", [request URL]] preferredStyle:UIAlertControllerStyleAlert];
			
			UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
#ifdef TRACE
				NSLog(@"[URLInterceptor] opening in 3rd party app: %@", [request URL]);
#endif
				[[UIApplication sharedApplication] openURL:[request URL] options:@{} completionHandler:nil];
			}];
			
			UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
			[alertController addAction:cancelAction];
			[alertController addAction:okAction];
			
			[[appDelegate webViewController] presentViewController:alertController animated:YES completion:nil];
		}
		
		return nil;
	}
	
#ifdef TRACE
	NSLog(@"[URLInterceptor] [Tab %@] initializing %@ to %@ (via %@)", wvt.tabIndex, [request HTTPMethod], [[request URL] absoluteString], [request mainDocumentURL]);
#endif
	return self;
}

- (NSMutableData *)data
{
	return _data;
}

- (void)appendData:(NSData *)newData
{
	if (_data == nil)
		_data = [[NSMutableData alloc] initWithData:newData];
	else
		[_data appendData:newData];
}

/*
 * We now have our request allocated and need to create a connection for it.
 * Set our User-Agent back to a default (without its per-tab hash) and check our URL blocker to see if we should even bother with this request.
 * If we proceed, pass it to CKHTTPConnection so we can do TLS options.
 */
- (void)startLoading
{
	NSMutableURLRequest *newRequest = [self.request mutableCopy];
	[newRequest setValue:userAgent forHTTPHeaderField:@"User-Agent"];
	[newRequest setHTTPShouldUsePipelining:YES];
	
	[self setActualRequest:newRequest];
	
	void (^cancelLoading)(void) = ^(void) {
		/* need to continue the chain with a blank response so downstream knows we're done */
		[self.client URLProtocol:self didReceiveResponse:[[NSURLResponse alloc] init] cacheStoragePolicy:NSURLCacheStorageNotAllowed];
		[self.client URLProtocolDidFinishLoading:self];
	};
	
	if ([NSURLProtocol propertyForKey:ORIGIN_KEY inRequest:newRequest]) {
		self.isOrigin = YES;
	}
	else if ([[newRequest URL] isEqual:[newRequest mainDocumentURL]]) {
#ifdef TRACE
		NSLog(@"[URLInterceptor] [Tab %@] considering as origin request: %@", wvt.tabIndex, [newRequest URL]);
#endif
		self.isOrigin = YES;
	}
	
	if (self.isOrigin) {
		[LocalNetworkChecker clearCache];
	}
	else {
		NSString *blocker = [URLBlocker blockingTargetForURL:[newRequest URL] fromMainDocumentURL:[newRequest mainDocumentURL]];
		if (blocker != nil) {
			[[wvt applicableURLBlockerTargets] setObject:@YES forKey:blocker];
			cancelLoading();
			return;
		}
	}
	
	/* some rules act on the host we're connecting to, and some act on the origin host */
	self.hostSettings = [HostSettings settingsOrDefaultsForHost:[[[self request] URL] host]];
	NSString *oHost = [[[self request] mainDocumentURL] host];
	if (oHost == nil || [oHost isEqualToString:@""] || [oHost isEqualToString:[[[self request] URL] host]])
		self.originHostSettings = self.hostSettings;
	else
		self.originHostSettings = [HostSettings settingsOrDefaultsForHost:oHost];

	/* check HSTS cache first to see if scheme needs upgrading */
	[newRequest setURL:[[appDelegate hstsCache] rewrittenURI:[[self request] URL]]];
	
	/* then check HTTPS Everywhere (must pass all URLs since some rules are not just scheme changes */
	NSArray *HTErules = [HTTPSEverywhere potentiallyApplicableRulesForHost:[[[self request] URL] host]];
	if (HTErules != nil && [HTErules count] > 0) {
		[newRequest setURL:[HTTPSEverywhere rewrittenURI:[[self request] URL] withRules:HTErules]];
		
		for (HTTPSEverywhereRule *HTErule in HTErules) {
			[[wvt applicableHTTPSEverywhereRules] setObject:@YES forKey:[HTErule name]];
		}
	}
	
	/* in case our URL changed/upgraded, send back to the webview so it knows what our protocol is for "//" assets */
	if (self.isOrigin && ![[[newRequest URL] absoluteString] isEqualToString:[[self.request URL] absoluteString]]) {
#ifdef TRACE_HOST_SETTINGS
		NSLog(@"[URLInterceptor] [Tab %@] canceling origin request to redirect %@ rewritten to %@", wvt.tabIndex, [[self.request URL] absoluteString], [[newRequest URL] absoluteString]);
#endif
		[wvt loadURL:[newRequest URL]];
		return;
	}
	
	if (!self.isOrigin) {
		if ([wvt secureMode] > WebViewTabSecureModeInsecure && ![[[[newRequest URL] scheme] lowercaseString] isEqualToString:@"https"]) {
			if ([self.originHostSettings settingOrDefault:HOST_SETTINGS_KEY_ALLOW_MIXED_MODE]) {
#ifdef TRACE_HOST_SETTINGS
				NSLog(@"[URLInterceptor] [Tab %@] allowing mixed-content request %@ from %@", wvt.tabIndex, [newRequest URL], [[newRequest mainDocumentURL] host]);
#endif
			}
			else {
				[wvt setSecureMode:WebViewTabSecureModeMixed];
#ifdef TRACE_HOST_SETTINGS
				NSLog(@"[URLInterceptor] [Tab %@] blocking mixed-content request %@ from %@", wvt.tabIndex, [newRequest URL], [[newRequest mainDocumentURL] host]);
#endif
				cancelLoading();
				return;
			}
		}
		
		if ([self.originHostSettings settingOrDefault:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS]) {
			if (![LocalNetworkChecker isHostOnLocalNet:[[newRequest mainDocumentURL] host]] && [LocalNetworkChecker isHostOnLocalNet:[[newRequest URL] host]]) {
#ifdef TRACE_HOST_SETTINGS
				NSLog(@"[URLInterceptor] [Tab %@] blocking request from origin %@ to local net host %@", wvt.tabIndex, [newRequest mainDocumentURL], [newRequest URL]);
#endif
				cancelLoading();
				return;
			}
		}
	}
	
	/* we're handling cookies ourself */
	[newRequest setHTTPShouldHandleCookies:NO];
	NSArray *cookies = [[appDelegate cookieJar] cookiesForURL:[newRequest URL] forTab:wvt.hash];
	if (cookies != nil && [cookies count] > 0) {
#ifdef TRACE_COOKIES
		NSLog(@"[URLInterceptor] [Tab %@] sending %lu cookie(s) to %@", wvt.tabIndex, [cookies count], [newRequest URL]);
#endif
		NSDictionary *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
		[newRequest setAllHTTPHeaderFields:headers];
	}

	/* add "do not track" header if it's enabled in the settings */
	if (sendDNT)
		[newRequest setValue:@"1" forHTTPHeaderField:@"DNT"];
	
	/* if we're trying to bypass the cache (forced reload), kill the If-None-Match header that gets put here automatically */
	if ([wvt forcingRefresh]) {
#ifdef TRACE
		NSLog(@"[URLInterceptor] [Tab %@] forcing refresh", wvt.tabIndex);
#endif
		[newRequest setValue:nil forHTTPHeaderField:@"If-None-Match"];
	}
	
	/* remember that we saw this to avoid a loop */
	[NSURLProtocol setProperty:@YES forKey:REWRITTEN_KEY inRequest:newRequest];
	
	[self setConnection:[CKHTTPConnection connectionWithRequest:newRequest delegate:self]];
}

- (void)stopLoading
{
	[self.connection cancel];
}

/*
 * CKHTTPConnection has established a connection (possibly with our TLS options), sent our request, and gotten a response.
 * Handle different types of content, inject JavaScript overrides, set fake CSP for WebView to process internally, etc.
 * Note that at this point, [self request] may be stale, so use [self actualRequest]
 */
- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response
{
#ifdef TRACE
	NSLog(@"[URLInterceptor] [Tab %@] got HTTP response %ld, content-type %@, length %lld for %@", wvt.tabIndex, (long)[response statusCode], [response MIMEType], [response expectedContentLength], [[[self actualRequest] URL] absoluteString]);
#endif
	
	encoding = 0;
	_data = nil;
	firstChunk = YES;

	contentType = CONTENT_TYPE_OTHER;
	NSString *ctype = [[self caseInsensitiveHeader:@"content-type" inResponse:response] lowercaseString];
	if (ctype != nil && ([ctype hasPrefix:@"text/html"] || [ctype hasPrefix:@"application/html"] || [ctype hasPrefix:@"application/xhtml+xml"]))
		contentType = CONTENT_TYPE_HTML;
	
	/* rewrite or inject Content-Security-Policy (and X-Webkit-CSP just in case) headers */
	NSString *CSPheader = nil;
	NSString *CSPmode = [self.originHostSettings setting:HOST_SETTINGS_KEY_CSP];

	if ([CSPmode isEqualToString:HOST_SETTINGS_CSP_STRICT])
		CSPheader = @"connect-src 'none'; default-src 'none'; font-src 'none'; media-src 'none'; object-src 'none'; sandbox allow-forms allow-top-navigation; script-src 'none'; style-src 'unsafe-inline' *; report-uri;";
	else if ([CSPmode isEqualToString:HOST_SETTINGS_CSP_BLOCK_CONNECT])
		CSPheader = @"connect-src 'none'; media-src 'none'; object-src 'none'; report-uri;";
	
	NSString *curCSP = [self caseInsensitiveHeader:@"content-security-policy" inResponse:response];
	
#ifdef TRACE_HOST_SETTINGS
	NSLog(@"[HostSettings] [Tab %@] setting CSP for %@ to %@ (via %@) (currently %@)", wvt.tabIndex, [[[self actualRequest] URL] host], CSPmode, [[[self actualRequest] mainDocumentURL] host], curCSP);
#endif

	NSMutableDictionary *mHeaders = [[NSMutableDictionary alloc] initWithDictionary:[response allHeaderFields]];
	
	/* don't bother rewriting with the header if we don't want a restrictive one (CSPheader) and the site doesn't have one (curCSP) */
	if (CSPheader != nil || curCSP != nil) {
		id foundCSP = nil;
		
		/* directives and their values (normal and nonced versions) to prepend */
		NSDictionary *wantedDirectives = @{
			@"child-src": @[ @"endlessipc:", @"endlessipc:" ],
			@"default-src" : @[ @"endlessipc:", [NSString stringWithFormat:@"'nonce-%@' endlessipc:", [self cspNonce]] ],
			@"frame-src": @[ @"endlessipc:", @"endlessipc:" ],
			@"script-src" : @[ @"", [NSString stringWithFormat:@"'nonce-%@'", [self cspNonce]] ],
		};

		for (id h in [mHeaders allKeys]) {
			NSString *hv = (NSString *)[[response allHeaderFields] valueForKey:h];
			
			if ([[h lowercaseString] isEqualToString:@"content-security-policy"] || [[h lowercaseString] isEqualToString:@"x-webkit-csp"]) {
				if ([CSPmode isEqualToString:HOST_SETTINGS_CSP_STRICT])
					/* disregard the existing policy since ours will be the most strict anyway */
					hv = CSPheader;
				
				/* merge in the things we require for any policy in case exiting policies would block them */
				hv = [URLInterceptor prependDirectivesIfExisting:wantedDirectives inCSPHeader:hv];
				
				[mHeaders setObject:hv forKey:h];
				foundCSP = hv;
			}
			else
				[mHeaders setObject:hv forKey:h];
		}
		
		if (!foundCSP && CSPheader) {
			[mHeaders setObject:CSPheader forKey:@"Content-Security-Policy"];
			[mHeaders setObject:CSPheader forKey:@"X-WebKit-CSP"];
			foundCSP = CSPheader;
		}
		
#ifdef TRACE_HOST_SETTINGS
		NSLog(@"[HostSettings] [Tab %@] CSP header is now %@", wvt.tabIndex, foundCSP);
#endif
	}
	
	/* rebuild our response with any modified headers */
	response = [[NSHTTPURLResponse alloc] initWithURL:[response URL] statusCode:[response statusCode] HTTPVersion:@"1.1" headerFields:mHeaders];

	/* save any cookies we just received */
	[[appDelegate cookieJar] setCookies:[NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:[[self actualRequest] URL]] forURL:[[self actualRequest] URL] mainDocumentURL:[wvt url] forTab:wvt.hash];
	
	/* in case of localStorage */
	[[appDelegate cookieJar] trackDataAccessForDomain:[[response URL] host] fromTab:wvt.hash];
	
	if ([[[self.request URL] scheme] isEqualToString:@"https"]) {
		NSString *hsts = [[(NSHTTPURLResponse *)response allHeaderFields] objectForKey:HSTS_HEADER];
		if (hsts != nil && ![hsts isEqualToString:@""]) {
			[[appDelegate hstsCache] parseHSTSHeader:hsts forHost:[[self.request URL] host]];
		}
	}
	
	if ([wvt secureMode] > WebViewTabSecureModeInsecure && ![[[[[self actualRequest] URL] scheme] lowercaseString] isEqualToString:@"https"]) {
		/* an element on the page was not sent over https but the initial request was, downgrade to mixed */
		if ([wvt secureMode] > WebViewTabSecureModeInsecure) {
			[wvt setSecureMode:WebViewTabSecureModeMixed];
		}
	}
	
	/* handle HTTP-level redirects */
	if (response.statusCode == 301 || response.statusCode == 302 || response.statusCode == 303 || response.statusCode == 307) {
		NSString *newURL = [self caseInsensitiveHeader:@"location" inResponse:response];
		if (newURL == nil || [newURL isEqualToString:@""])
			NSLog(@"[URLInterceptor] [Tab %@] got %ld redirect at %@ but no location header", wvt.tabIndex, (long)response.statusCode, [[self actualRequest] URL]);
		else {
			NSMutableURLRequest *newRequest = [[NSMutableURLRequest alloc] init];

			/* 307 redirects are supposed to retain the method when redirecting but others should go back to GET */
			if (response.statusCode == 307)
				[newRequest setHTTPMethod:[[self actualRequest] HTTPMethod]];
			else
				[newRequest setHTTPMethod:@"GET"];
			
			/* strangely, if we pass [NSURL URLWithString:/ relativeToURL:[NSURL https://blah/asdf/]] as the URL for the new request, it treats it as just "/" with no domain information so we have to build the relative URL, turn it into a string, then back to a URL */
			NSString *aURL = [[NSURL URLWithString:newURL relativeToURL:[[self actualRequest] URL]] absoluteString];
			[newRequest setURL:[NSURL URLWithString:aURL]];
#ifdef TRACE
			NSLog(@"[URLInterceptor] [Tab %@] got %ld redirect from %@ to %@", wvt.tabIndex, (long)response.statusCode, [[[self actualRequest] URL] absoluteString], aURL);
#endif
			[newRequest setMainDocumentURL:[[self actualRequest] mainDocumentURL]];
			
			[NSURLProtocol setProperty:[NSNumber numberWithLong:wvt.hash] forKey:WVT_KEY inRequest:newRequest];

			/* if we're being redirected from secure back to insecure, we might be stuck in a loop from an HTTPSEverywhere rule */
			if ([[[[self actualRequest] URL] scheme] isEqualToString:@"https"] && [[[newRequest URL] scheme] isEqualToString:@"http"])
				[HTTPSEverywhere noteInsecureRedirectionForURL:[[self actualRequest] URL]];
			
			/* process it all over again */
			[NSURLProtocol removePropertyForKey:REWRITTEN_KEY inRequest:newRequest];
			[[self client] URLProtocol:self wasRedirectedToRequest:newRequest redirectResponse:response];
		}
		
		[[self connection] cancel];
		[[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:@{ ORIGIN_KEY: (self.isOrigin ? @YES : @NO )}]];
		return;
	}
	
	NSString *content_encoding = [self caseInsensitiveHeader:@"content-encoding" inResponse:response];
	if (content_encoding != nil) {
		if ([content_encoding isEqualToString:@"deflate"])
			encoding = ENCODING_DEFLATE;
		else if ([content_encoding isEqualToString:@"gzip"])
			encoding = ENCODING_GZIP;
		else
			NSLog(@"[URLInterceptor] [Tab %@] unknown content encoding \"%@\"", wvt.tabIndex, content_encoding);
	}
	
	[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
}

- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveSecTrust:(SecTrustRef)secTrustRef certificate:(SSLCertificate *)certificate
{
	if (self.isOrigin)
		[wvt setSSLCertificate:certificate];
}

- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveData:(NSData *)data
{
	[self appendData:data];
	
	NSData *newData;
	if (encoding) {
		/*
		 * Try to un-gzip the data we've received so far.  If we get nil (it's incomplete gzip data),
		 * continue to buffer it before passing it along. If we *can* ungzip it, pass the ugzip'd data
		 * along and reset the buffer.
		 */
		if (encoding == ENCODING_DEFLATE)
			newData = [_data zlibInflate];
		else if (encoding == ENCODING_GZIP)
			newData = [_data gzipInflate];
	}
	else
		newData = [[NSData alloc] initWithBytes:[data bytes] length:[data length]];
	
	if (newData != nil) {
		if (firstChunk) {
			/* we only need to do injection for top-level docs */
			if (self.isOrigin) {
				NSMutableData *tData = [[NSMutableData alloc] init];
				if (contentType == CONTENT_TYPE_HTML)
					/* prepend a doctype to force into standards mode and throw in any javascript overrides */
					[tData appendData:[[NSString stringWithFormat:@"<!DOCTYPE html><script type=\"text/javascript\" nonce=\"%@\">%@</script>", [self cspNonce], [[self class] javascriptToInject]] dataUsingEncoding:NSUTF8StringEncoding]];
				
				[tData appendData:newData];
				newData = tData;
			}

			firstChunk = NO;
		}
		
		/* clear our running buffer of data for this request */
		_data = nil;
	}
	[self.client URLProtocol:self didLoadData:newData];
}

- (void)HTTPConnectionDidFinishLoading:(CKHTTPConnection *)connection {
	[self.client URLProtocolDidFinishLoading:self];
	[self setConnection:nil];
	_data = nil;
}

- (void)HTTPConnection:(CKHTTPConnection *)connection didFailWithError:(NSError *)error {
#ifdef TRACE
	NSLog(@"[URLInterceptor] [Tab %@] failed loading %@: %@", wvt.tabIndex, [[[self actualRequest] URL] absoluteString], error);
#endif
	
	NSMutableDictionary *ui = [[NSMutableDictionary alloc] initWithDictionary:[error userInfo]];
	[ui setObject:(self.isOrigin ? @YES : @NO) forKeyedSubscript:ORIGIN_KEY];
	
	[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:[error domain] code:[error code] userInfo:ui]];
	[self setConnection:nil];
	_data = nil;
}

- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	NSURLCredential *nsuc;
	
	/* if we have existing credentials for this realm, try it first */
	if ([challenge previousFailureCount] == 0) {
		NSDictionary *d = [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:[challenge protectionSpace]];
		if (d != nil) {
			for (id u in d) {
				nsuc = [d objectForKey:u];
				break;
			}
		}
	}
	
	/* no credentials, prompt the user */
	if (nsuc == nil) {
		dispatch_async(dispatch_get_main_queue(), ^{
			UIAlertController *uiac = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Authentication Required", nil) message:@"" preferredStyle:UIAlertControllerStyleAlert];

			if ([[challenge protectionSpace] realm] != nil && ![[[challenge protectionSpace] realm] isEqualToString:@""])
				[uiac setMessage:[NSString stringWithFormat:@"%@: \"%@\"", [[challenge protectionSpace] host], [[challenge protectionSpace] realm]]];
			else
				[uiac setMessage:[[challenge protectionSpace] host]];
			
			[uiac addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				textField.placeholder = NSLocalizedString(@"Log In", nil);
			}];
			
			[uiac addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				 textField.placeholder = NSLocalizedString(@"Password", @"Password");
				 textField.secureTextEntry = YES;
			}];
			
			[uiac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
				[[challenge sender] cancelAuthenticationChallenge:challenge];
				[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:@{ ORIGIN_KEY: @YES }]];
			}]];
			
			[uiac addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Log In", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
				UITextField *login = uiac.textFields.firstObject;
				UITextField *password = uiac.textFields.lastObject;

				NSURLCredential *nsuc = [[NSURLCredential alloc] initWithUser:[login text] password:[password text] persistence:NSURLCredentialPersistenceForSession];
				[[NSURLCredentialStorage sharedCredentialStorage] setCredential:nsuc forProtectionSpace:[challenge protectionSpace]];
				
				[[challenge sender] useCredential:nsuc forAuthenticationChallenge:challenge];
			}]];
			
			[[appDelegate webViewController] presentViewController:uiac animated:YES completion:nil];
		});
	}
	else {
		[[NSURLCredentialStorage sharedCredentialStorage] setCredential:nsuc forProtectionSpace:[challenge protectionSpace]];
		[[challenge sender] useCredential:nsuc forAuthenticationChallenge:challenge];
		
		/* XXX: crashes in WebCore */
		//[self.client URLProtocol:self didReceiveAuthenticationChallenge:challenge];
	}
}

- (void)HTTPConnection:(CKHTTPConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	[self.client URLProtocol:self didCancelAuthenticationChallenge:challenge];
}

- (void)HTTPConnection:(CKHTTPConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
}

- (NSString *)caseInsensitiveHeader:(NSString *)header inResponse:(NSHTTPURLResponse *)response
{
	NSString *o;
	for (id h in [response allHeaderFields]) {
		if ([[h lowercaseString] isEqualToString:[header lowercaseString]]) {
			o = [[response allHeaderFields] objectForKey:h];
			
			/* XXX: does webview always honor the first matching header or the last one? */
			break;
		}
	}
	
	return o;
}

- (NSString *)cspNonce
{
	if (!_cspNonce) {
		/*
		 * from https://w3c.github.io/webappsec-csp/#security-nonces:
		 *
		 * "The generated value SHOULD be at least 128 bits long (before encoding), and SHOULD
		 * "be generated via a cryptographically secure random number generator in order to
		 * "ensure that the value is difficult for an attacker to predict.
		 */
		
		NSMutableData *data = [NSMutableData dataWithLength:16];
		if (SecRandomCopyBytes(kSecRandomDefault, 16, data.mutableBytes) != 0)
			abort();
		
		_cspNonce = [data base64EncodedStringWithOptions:0];
	}
	
	return _cspNonce;
}

@end


#ifdef USE_DUMMY_URLINTERCEPTOR

/*
 * A simple NSURLProtocol handler to swap in for URLInterceptor, which does less mucking around.
 * Useful for troubleshooting.
 */
 
@implementation DummyURLInterceptor

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	if ([NSURLProtocol propertyForKey:REWRITTEN_KEY inRequest:request] != nil)
		return NO;
	
	NSString *scheme = [[[request URL] scheme] lowercaseString];
	if ([scheme isEqualToString:@"data"] || [scheme isEqualToString:@"file"])
		return NO;
	
	return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	return request;
}

- (void)startLoading
{
	NSLog(@"[DummyURLInterceptor] [%lu] start loading %@ %@", self.hash, [self.request HTTPMethod], [self.request URL]);

	NSMutableURLRequest *newRequest = [self.request mutableCopy];
	[NSURLProtocol setProperty:@YES forKey:REWRITTEN_KEY inRequest:newRequest];
	self.connection = [NSURLConnection connectionWithRequest:newRequest delegate:self];
}

- (void)stopLoading
{
	[self.connection cancel];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	NSLog(@"[DummyURLInterceptor] [%lu] got HTTP data with size %lu for %@", self.hash, [data length], [[connection originalRequest] URL]);
	[self.client URLProtocol:self didLoadData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	NSMutableDictionary *ui = [[NSMutableDictionary alloc] initWithDictionary:[error userInfo]];
	[ui setObject:(self.isOrigin ? @YES : @NO) forKeyedSubscript:ORIGIN_KEY];
	
	[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:[error domain] code:[error code] userInfo:ui]];
	self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	NSLog(@"[DummyURLInterceptor] [%lu] got HTTP response content-type %@, length %lld for %@", self.hash, [response MIMEType], [response expectedContentLength], [[connection originalRequest] URL]);
	[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self.client URLProtocolDidFinishLoading:self];
	self.connection = nil;
}

@end

#endif
