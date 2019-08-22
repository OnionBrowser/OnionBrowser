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
// #import "LocalNetworkChecker.h"
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
	
	/*
	 * Videos load without our modified User-Agent (which normally has a per-tab hash appended to it to be able to match
	 * it to the proper tab) but it does have its own UA which starts with "AppleCoreMedia/".  Assume it came from the
	 * current tab and hope for the best.
	 */
	if (wvt == nil && ([[[[request URL] scheme] lowercaseString] isEqualToString:@"http"] || [[[[request URL] scheme] lowercaseString] isEqualToString:@"https"]) && [[ua substringToIndex:15] isEqualToString:@"AppleCoreMedia/"]) {
#ifdef TRACE
		NSLog(@"[URLInterceptor] AppleCoreMedia request with no matching WebViewTab, binding to current tab: %@", [request URL]);
#endif
		wvt = [[appDelegate webViewController] curWebViewTab];
	}
	
	if (wvt == nil) {
		NSLog(@"[URLInterceptor] request for %@ with no matching WebViewTab! (main URL %@, UA hash %@)", [request URL], [request mainDocumentURL], wvthash);
		
		[client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:@{ ORIGIN_KEY: @YES }]];
		
		if (![[[[request URL] scheme] lowercaseString] isEqualToString:@"http"] && ![[[[request URL] scheme] lowercaseString] isEqualToString:@"https"]) {
			/* iOS 10 blocks canOpenURL: requests, so we just have to assume these go somewhere */
			
			/* about: URLs should just return nothing */
			if ([[[request URL] scheme] isEqualToString:@"about"])
				return nil;

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
	
    /*
	if (self.isOrigin) {
		[LocalNetworkChecker clearCache];
	}
    */
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

	/* set our proper UA, or use this host's version */
	NSString *customUA = [self.originHostSettings settingOrDefault:HOST_SETTINGS_KEY_USER_AGENT];
	if (customUA == nil || [customUA isEqualToString:@""])
		[newRequest setValue:userAgent forHTTPHeaderField:@"User-Agent"];
	else {
#ifdef TRACE
		NSLog(@"[URLInterceptor] [Tab %@] setting custom UA: %@", wvt.tabIndex, customUA);
#endif
		[newRequest setValue:customUA forHTTPHeaderField:@"User-Agent"];
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
		
        /*
		if ([self.originHostSettings settingOrDefault:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS]) {
			if (![LocalNetworkChecker isHostOnLocalNet:[[newRequest mainDocumentURL] host]] && [LocalNetworkChecker isHostOnLocalNet:[[newRequest URL] host]]) {
#ifdef TRACE_HOST_SETTINGS
				NSLog(@"[URLInterceptor] [Tab %@] blocking request from origin %@ to local net host %@", wvt.tabIndex, [newRequest mainDocumentURL], [newRequest URL]);
#endif
				cancelLoading();
				return;
			}
		}
        */
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
			
			/* if the new URL is not absolute, try to build one relative to the current URL */
			NSURL *tURL = [NSURL URLWithString:newURL relativeToURL:[[self actualRequest] URL]];
			
			/* but if that failed, the new URL is probably absolute already */
			if (tURL == nil)
				tURL = [NSURL URLWithString:newURL];
			
			if (tURL == nil) {
				NSLog(@"[URLInterceptor] [Tab %@] failed building URL from %ld redirect to %@", wvt.tabIndex, (long)response.statusCode, newURL);
				[[self connection] cancel];
				[[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:@{ ORIGIN_KEY: (self.isOrigin ? @YES : @NO )}]];
				return;
			}
			
			/* strangely, if we pass [NSURL URLWithString:/ relativeToURL:[NSURL https://blah/asdf/]] as the URL for the new request, it treats it as just "/" with no domain information so we have to build the relative URL, turn it into a string, then back to a URL */
			NSURLComponents *newURLC = [[NSURLComponents alloc] initWithString:[tURL absoluteString]];
			
			/* if we have no anchor in the new location, but the original request did, we need to preserve it */
			if ([newURLC fragment] == nil || [[newURLC fragment] isEqualToString:@""]) {
				if ([[[self actualRequest] URL] fragment] != nil && ![[[[self actualRequest] URL] fragment] isEqualToString:@""])
					[newURLC setFragment:[[[self actualRequest] URL] fragment]];
			}
			
			[newRequest setURL:[newURLC URL]];

#ifdef TRACE
			NSLog(@"[URLInterceptor] [Tab %@] got %ld redirect from %@ to %@", wvt.tabIndex, (long)response.statusCode, [[[self actualRequest] URL] absoluteString], [[newRequest URL] absoluteURL]);
#endif
			[newRequest setMainDocumentURL:[[self actualRequest] mainDocumentURL]];
			
			[NSURLProtocol setProperty:[NSNumber numberWithLong:wvt.hash] forKey:WVT_KEY inRequest:newRequest];

			/* if we're being redirected from secure back to insecure, we might be stuck in a loop from an HTTPSEverywhere rule */
			if ([[[[self actualRequest] URL] scheme] isEqualToString:@"https"] && [[[newRequest URL] scheme] isEqualToString:@"http"])
				[HTTPSEverywhere noteInsecureRedirectionForURL:[[self actualRequest] URL] toURL:[newRequest URL]];
			
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
