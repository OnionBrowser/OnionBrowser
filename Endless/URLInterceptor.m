/*
 * CKHTTP portions of this file are from Onion Browser
 * Copyright (c) 2012-2014 Mike Tigas <mike@tig.as>
 */

#import "AppDelegate.h"
#import "HSTSCache.h"
#import "HTTPSEverywhere.h"
#import "LocalNetworkChecker.h"
#import "URLBlocker.h"
#import "URLInterceptor.h"
#import "WebViewTab.h"

#import "NSData+CocoaDevUsersAdditions.h"

@implementation URLInterceptor

static AppDelegate *appDelegate;
static BOOL sendDNT = true;
static BOOL blockIntoLocalNets = true;
static NSMutableArray *tmpAllowed;

WebViewTab *wvt;
NSString *userAgent;

static NSString *_javascriptToInject;
+ (NSString *)javascriptToInject
{
	if (!_javascriptToInject) {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"injected" ofType:@"js"];
		_javascriptToInject = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	}
	
	return _javascriptToInject;
}

+ (void)setBlockIntoLocalNets:(BOOL)val
{
	blockIntoLocalNets = val;
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
	if (wvt == nil) {
		for (int i = 0; i < [tmpAllowed count]; i++) {
			if ([[tmpAllowed[i] absoluteString] isEqualToString:[url absoluteString]])
				found = i;
		}
		
		if (found > -1) {
			NSLog(@"[URLInterceptor] temporarily allowing %@ from allowed list with no matching WebViewTab", url);
			[tmpAllowed removeObjectAtIndex:found];
		}
	}
	
	return (found > -1);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	return request;
}

- (NSMutableData *)data {
	return _data;
}

- (void)appendData:(NSData *)newData {
	if (_data == nil)
		_data = [[NSMutableData alloc] initWithData:newData];
	else
		[_data appendData:newData];
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
		
		[client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
		
		if (![[[[request URL] scheme] lowercaseString] isEqualToString:@"http"] && ![[[[request URL] scheme] lowercaseString] isEqualToString:@"https"]) {
			if ([[UIApplication sharedApplication] canOpenURL:[request URL]]) {
				UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Open In External App" message:[NSString stringWithFormat:@"Allow URL to be opened by external app? This may compromise your privacy.\n\n%@", [request URL]] preferredStyle:UIAlertControllerStyleAlert];
				
				UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
#ifdef TRACE
					NSLog(@"[URLInterceptor] opening in 3rd party app: %@", [request URL]);
#endif
					[[UIApplication sharedApplication] openURL:[request URL]];
				}];
				
				UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
				[alertController addAction:cancelAction];
				[alertController addAction:okAction];
				
				[[appDelegate webViewController] presentViewController:alertController animated:YES completion:nil];
			}
		}
		
		return nil;
	}
	
#ifdef TRACE
	NSLog(@"[URLInterceptor] [Tab %@] initializing %@ to %@ (via %@)", wvt.tabIndex, [request HTTPMethod], [[request URL] absoluteString], [request mainDocumentURL]);
#endif
	return self;
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
	else if ([URLBlocker shouldBlockURL:[newRequest URL] fromMainDocumentURL:[newRequest mainDocumentURL]]) {
		cancelLoading();
		return;
	}
	
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
	
	if (!self.isOrigin) {
		if ([wvt secureMode] > WebViewTabSecureModeInsecure && ![[[[newRequest URL] scheme] lowercaseString] isEqualToString:@"https"]) {
			[wvt setSecureMode:WebViewTabSecureModeMixed];
			NSLog(@"[URLInterceptor] [Tab %@] blocking mixed-content request %@", wvt.tabIndex, [newRequest URL]);
			cancelLoading();
			return;
		}
		
		if (blockIntoLocalNets) {
			if (![LocalNetworkChecker isHostOnLocalNet:[[newRequest mainDocumentURL] host]] && [LocalNetworkChecker isHostOnLocalNet:[[newRequest URL] host]]) {
				NSLog(@"[URLInterceptor] [Tab %@] blocking request from origin %@ to local net host %@", wvt.tabIndex, [newRequest mainDocumentURL], [newRequest URL]);
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
	
	/* remember that we saw this to avoid a loop */
	[NSURLProtocol setProperty:@YES forKey:REWRITTEN_KEY inRequest:newRequest];
	
	CKHTTPConnection *con = [CKHTTPConnection connectionWithRequest:newRequest delegate:self];
	[self setConnection:con];
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
	NSLog(@"[URLInterceptor] [Tab %@] got HTTP response %ld with content-type %@ for %@", wvt.tabIndex, (long)[response statusCode], [response MIMEType], [[[self actualRequest] URL] absoluteString]);
#endif
	
	encoding = 0;
	_data = nil;
	firstChunk = YES;

	contentType = CONTENT_TYPE_OTHER;
	NSString *ctype = [self caseInsensitiveHeader:@"content-type" inResponse:response];
	if (ctype != nil) {
		if ([ctype hasPrefix:@"text/html"] || [ctype hasPrefix:@"application/html"] || [ctype hasPrefix:@"application/xhtml+xml"])
			contentType = CONTENT_TYPE_HTML;
		else if ([ctype hasPrefix:@"application/javascript"] || [ctype hasPrefix:@"text/javascript"] || [ctype hasPrefix:@"application/x-javascript"] || [ctype hasPrefix:@"text/x-javascript"])
			contentType = CONTENT_TYPE_JAVASCRIPT;
		else if ([ctype hasPrefix:@"image/"])
			contentType = CONTENT_TYPE_IMAGE;
	}

#if 0
	/* TODO: adapt this into a proper preference setting */
	
	/* If content-policy ("javascript") setting is CONTENTPOLICY_STRICT or CONTENTPOLICY_BLOCK_CONNECT,
	 * modify incoming headers to turn on the "content-security-policy" and "x-webkit-csp" headers accordingly.
	 * http://www.html5rocks.com/en/tutorials/security/content-security-policy/#policy-applies-to-a-wide-variety-of-resources
	 * http://www.w3.org/TR/CSP/
	 */
	if (([[settings valueForKey:@"javascript"] integerValue] == CONTENTPOLICY_STRICT)
	    && ([response isKindOfClass: [NSHTTPURLResponse class]] == YES)) {
		// In the STRICT case, we're going to drop any content-security-policy headers since we just want
		// our strictest-possible header.
		NSMutableDictionary *mHeaders = [NSMutableDictionary dictionary];
		for(id h in response.allHeaderFields) {
			if(![[h lowercaseString] isEqualToString:@"content-security-policy"] && ![[h lowercaseString] isEqualToString:@"x-webkit-csp"]  && ![[h lowercaseString] isEqualToString:@"cache-control"]) {
				// Delete existing content-security-policy headers & cache header (since we rely on writing our on strict ones)
				[mHeaders setObject:response.allHeaderFields[h] forKey:h];
			}
		}
		[mHeaders setObject:@"script-src 'none';media-src 'none';object-src 'none';connect-src 'none';font-src 'none';sandbox allow-forms allow-top-navigation;style-src 'unsafe-inline' *;"
			     forKey:@"Content-Security-Policy"];
		[mHeaders setObject:@"script-src 'none';media-src 'none';object-src 'none';connect-src 'none';font-src 'none';sandbox allow-forms allow-top-navigation;style-src 'unsafe-inline' *;"
			     forKey:@"X-Webkit-CSP"];
		[mHeaders setObject:@"max-age=0, no-cache, no-store, must-revalidate"
			     forKey:@"Cache-Control"];
		response = [[NSHTTPURLResponse alloc]
			    initWithURL:response.URL statusCode:response.statusCode
			    HTTPVersion:@"1.1" headerFields:mHeaders];
	} else if (([[settings valueForKey:@"javascript"] integerValue] == CONTENTPOLICY_BLOCK_CONNECT)
		   && ([response isKindOfClass: [NSHTTPURLResponse class]] == YES)){
		// In the "block XHR/Media/WebSocket" case, we'll prepend
		// "connect-src 'none';media-src 'none';object-src 'none';"
		// to an existing CSP header OR we'll add that header if there isn't already an existing one.
		// (Basically as the STRICT case, but allowing script/fonts.)
		NSMutableDictionary *mHeaders = [NSMutableDictionary dictionary];
		Boolean editedCSP = NO;
		Boolean editedWebkitCSP = NO;
		for (id h in response.allHeaderFields) {
			if([[h lowercaseString] isEqualToString:@"content-security-policy"]) {
				NSString *newHeader = [NSString stringWithFormat:@"connect-src 'none';media-src 'none';object-src 'none';%@", response.allHeaderFields[h]];
				[mHeaders setObject:newHeader forKey:h];
				editedCSP = YES;
			} else if ([[h lowercaseString] isEqualToString:@"x-webkit-csp"]) {
				NSString *newHeader = [NSString stringWithFormat:@"connect-src 'none';media-src 'none';object-src 'none';%@", response.allHeaderFields[h]];
				[mHeaders setObject:newHeader forKey:h];
				editedWebkitCSP = YES;
			} else if ([[h lowercaseString] isEqualToString:@"cache-control"]) {
				// Don't pass along existing Cache-Control header
			} else {
				// Non-CSP header, just pass it on.
				[mHeaders setObject:response.allHeaderFields[h] forKey:h];
			}
		}
		if (!editedCSP) {
			[mHeaders setObject:@"connect-src 'none';media-src 'none';object-src 'none';"
				     forKey:@"Content-Security-Policy"];
		}
		if (!editedWebkitCSP) {
			[mHeaders setObject:@"connect-src 'none';media-src 'none';object-src 'none';"
				     forKey:@"X-Webkit-CSP"];
		}
		[mHeaders setObject:@"max-age=0, no-cache, no-store, must-revalidate"
			     forKey:@"Cache-Control"];
		response = [[NSHTTPURLResponse alloc]
			    initWithURL:response.URL statusCode:response.statusCode
			    HTTPVersion:@"1.1" headerFields:mHeaders];
	}
	else
#endif
	{
		// Normal case: let's still disable cache
		NSMutableDictionary *mHeaders = [NSMutableDictionary dictionary];
		for (id h in response.allHeaderFields) {
			if (![[h lowercaseString] isEqualToString:@"cache-control"]) {
				[mHeaders setObject:response.allHeaderFields[h] forKey:h];
			}
		}
		[mHeaders setObject:@"max-age=0, no-cache, no-store, must-revalidate" forKey:@"Cache-Control"];
		response = [[NSHTTPURLResponse alloc] initWithURL:response.URL statusCode:response.statusCode HTTPVersion:@"1.1" headerFields:mHeaders];
	}
	
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
	
	if (self.isOrigin) {
		if ([[[[[self actualRequest] URL] scheme] lowercaseString] isEqualToString:@"https"]) {
			/* initial request was over https, start considering us secure */
			
			if (self.evOrgName != nil && ![self.evOrgName isEqualToString:@""]) {
				[wvt setSecureMode:WebViewTabSecureModeSecureEV];
				[wvt setEvOrgName:self.evOrgName];
			}
			else {
				[wvt setSecureMode:WebViewTabSecureModeSecure];
			}
		}
	}
	else if ([wvt secureMode] > WebViewTabSecureModeInsecure && ![[[[[self actualRequest] URL] scheme] lowercaseString] isEqualToString:@"https"]) {
		/* an element on the page was not sent over https but the initial request was, downgrade to mixed */
		if ([wvt secureMode] > WebViewTabSecureModeInsecure) {
			[wvt setSecureMode:WebViewTabSecureModeMixed];
		}
	}
	
	/* handle HTTP-level redirects */
	if ((response.statusCode == 301) || (response.statusCode == 302) || (response.statusCode == 307)) {
		NSString *newURL = [self caseInsensitiveHeader:@"location" inResponse:response];
		if (newURL == nil || [newURL isEqualToString:@""])
			NSLog(@"[URLInterceptor] got %ld redirect at %@ but no location header", (long)response.statusCode, [[self actualRequest] URL]);
		else {
			NSMutableURLRequest *newRequest = [[self actualRequest] mutableCopy];
			[newRequest setHTTPShouldUsePipelining:YES];
			
			/* strangely, if we pass [NSURL URLWithString:/ relativeToURL:[NSURL https://blah/asdf/]] as the URL for the new request, it treats it as just "/" with no domain information so we have to build the relative URL, turn it into a string, then back to a URL */
			NSString *aURL = [[NSURL URLWithString:newURL relativeToURL:[[self actualRequest] URL]] absoluteString];
			[newRequest setURL:[NSURL URLWithString:aURL]];
#ifdef DEBUG
			NSLog(@"[URLInterceptor] got %ld redirect from %@ to %@", (long)response.statusCode, [[[self actualRequest] URL] absoluteString], aURL);
#endif
			if ([NSURLProtocol propertyForKey:ORIGIN_KEY inRequest:[self actualRequest]])
				[newRequest setMainDocumentURL:[NSURL URLWithString:aURL]];
			
			[NSURLProtocol setProperty:[NSNumber numberWithLong:wvt.hash] forKey:WVT_KEY inRequest:newRequest];

			/* if we're being redirected from secure back to insecure, we might be stuck in a loop from an HTTPSEverywhere rule */
			if ([[[[self actualRequest] URL] scheme] isEqualToString:@"https"] && [[[newRequest URL] scheme] isEqualToString:@"http"])
				[HTTPSEverywhere noteInsecureRedirectionForURL:[[self actualRequest] URL]];
			
			/* process it all over again */
			[NSURLProtocol removePropertyForKey:REWRITTEN_KEY inRequest:newRequest];
			[[self client] URLProtocol:self wasRedirectedToRequest:newRequest redirectResponse:response];
		}
		
		[[self connection] cancel];
		[[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
		return;
	}
	
	/* for some reason, passing the response directly doesn't always properly set the separate mimetype and content-encoding bits, so attempt to parse them out */
	
	NSString *content_type = [self caseInsensitiveHeader:@"content-type" inResponse:response];

	/* "text/html; charset=UTF-8" */
	if (content_type == nil || [content_type isEqualToString:@""])
		content_type = @"text/plain";
	
	NSArray *ctparts = [content_type componentsSeparatedByString:@";"];
	
	/* "text/html" */
	NSString *mime = [ctparts objectAtIndex:0];
	
	NSString *content_encoding = [self caseInsensitiveHeader:@"content-encoding" inResponse:response];
	if (content_encoding != nil) {
		if ([content_encoding isEqualToString:@"deflate"])
			encoding = ENCODING_DEFLATE;
		else if ([content_encoding isEqualToString:@"gzip"])
			encoding = ENCODING_GZIP;
	}

	NSString *charset = @"UTF-8";
	NSArray *charset_bits = [content_type componentsSeparatedByString:@"charset="];
	if ([charset_bits count] > 1)
		charset = [[charset_bits objectAtIndex:1] componentsSeparatedByString:@";"][0];
	
#ifdef DEBUG
	NSLog(@"[URLInterceptor] [Tab %@] content-type=%@, charset=%@, encoding=%@", wvt.tabIndex, mime, charset, content_encoding);
#endif
	
	NSURLResponse *textResponse;
	if ([[[[response URL] scheme] lowercaseString] isEqualToString:@"http"] || [[[[response URL] scheme] lowercaseString] isEqualToString:@"https"])
		textResponse = [[NSHTTPURLResponse alloc] initWithURL:[response URL] statusCode:[response statusCode] HTTPVersion:@"1.1" headerFields:[response allHeaderFields]];
	else
		textResponse = [[NSURLResponse alloc] initWithURL:[response URL] MIMEType:mime expectedContentLength:[response expectedContentLength] textEncodingName:charset];
	
	[self.client URLProtocol:self didReceiveResponse:textResponse cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
}

- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveData:(NSData *)data {
	[self appendData:data];
	
	NSData *newData;
	if (encoding) {
		// Try to un-gzip the data we've received so far.
		// If we get nil (it's incomplete gzip data), continue to
		// buffer it before passing it along. If we *can* ungzip it,
		// pass the ugzip'd data along and reset the buffer.
		if (encoding == ENCODING_DEFLATE)
			newData = [_data zlibInflate];
		else if (encoding == ENCODING_GZIP)
			newData = [_data gzipInflate];
	}
	else
		newData = [[NSData alloc] initWithBytes:[data bytes] length:[data length]];
	
	if (newData != nil) {
		if (firstChunk) {
			if (contentType == CONTENT_TYPE_HTML)
				newData = [self htmlDataWithJavascriptInjection:newData];
			else if (contentType == CONTENT_TYPE_JAVASCRIPT)
				newData = [self javascriptDataWithJavascriptInjection:newData];

			firstChunk = NO;
		}
		
		/* clear our running buffer of data for this request */
		_data = nil;
	}

	[self.client URLProtocol:self didLoadData:newData];
}

/* TODO - this is no longer hooked up to anything */
- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	SecTrustRef trustRef = [[challenge protectionSpace] serverTrust];
	
	/*
	 CFIndex count = SecTrustGetCertificateCount(trustRef);
	 for (CFIndex i = 0; i < count; i++) {
		SecCertificateRef certRef = SecTrustGetCertificateAtIndex(trustRef, i);
		CFStringRef certSummary = SecCertificateCopySubjectSummary(certRef);
		NSLog(@"cert: %@", certSummary);
	 }
	 */
	
	NSDictionary *trust = (__bridge NSDictionary*)SecTrustCopyResult(trustRef);
	id ev = [trust objectForKey:(__bridge NSString *)kSecTrustExtendedValidation];
	if (ev != nil && (__bridge CFBooleanRef)ev == kCFBooleanTrue) {
		NSString *orgname = (NSString *)[trust objectForKey:(__bridge NSString *)kSecTrustOrganizationName];
#ifdef DEBUG
		NSLog(@"[Tab %@] cert for %@ has EV, registered to %@", wvt.tabIndex, [[self.request URL] host], orgname);
#endif
		if ([NSURLProtocol propertyForKey:ORIGIN_KEY inRequest:self.request] && [[[[self.request URL] host] lowercaseString] isEqualToString:[[[wvt url] host] lowercaseString]]) {
			[self setEvOrgName:orgname];
		}
	}
	
	/* TODO: check for blacklisted certs or CAs? */
	// [[challenge sender] cancelAuthenticationChallenge:challenge];
	
	[[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
	
	[self.client URLProtocol:self didReceiveAuthenticationChallenge:challenge];
}

- (void)HTTPConnection:(CKHTTPConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	[self.client URLProtocol:self didCancelAuthenticationChallenge:challenge];
}

- (void)HTTPConnectionDidFinishLoading:(CKHTTPConnection *)connection {
	[self.client URLProtocolDidFinishLoading:self];
	[self setConnection:nil];
	_data = nil;
}

- (void)HTTPConnection:(CKHTTPConnection *)connection didFailWithError:(NSError *)error {
	[self.client URLProtocol:self didFailWithError:error];
	[self setConnection:nil];
	_data = nil;
}

- (NSData *)htmlDataWithJavascriptInjection:incomingData {
	NSMutableData *newData = [[NSMutableData alloc] init];
	
	// Prepend a DOCTYPE (to force into standards mode) and throw in any javascript overrides
	[newData appendData:[[NSString stringWithFormat:@"<!DOCTYPE html><script>%@</script>", [[self class] javascriptToInject]] dataUsingEncoding:NSUTF8StringEncoding]];
	[newData appendData:incomingData];
	return newData;
}

- (NSData *)javascriptDataWithJavascriptInjection:incomingData {
	NSMutableData *newData = [[NSMutableData alloc] init];
	[newData appendData:[[NSString stringWithFormat:@"%@\n", [[self class] javascriptToInject]] dataUsingEncoding:NSUTF8StringEncoding]];
	[newData appendData:incomingData];
	return newData;
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

@end
