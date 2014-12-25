#import "AppDelegate.h"
#import "CookieWhitelist.h"
#import "HTTPSEverywhere.h"
#import "URLBlocker.h"
#import "URLInterceptor.h"
#import "WebViewTab.h"

@implementation URLInterceptor

static AppDelegate *appDelegate;
static BOOL sendDNT = true;

WebViewTab *wvt;

+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
	if ([NSURLProtocol propertyForKey:REWRITTEN_KEY inRequest:request] != nil)
		/* already mucked with this request */
		return NO;
	
	NSString *scheme = [[[request URL] scheme] lowercaseString];
	if ([scheme isEqualToString:@"data"] || [scheme isEqualToString:@"file"])
		/* can't really do anything for these URLs */
		return NO;
	
	if (appDelegate == nil)
		appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
	return request;
}

+ (void)setSendDNT:(BOOL)val
{
	sendDNT = val;
}

- (void)startLoading
{
	wvt = nil;
	self.origRequest = self.request;
	
	NSMutableURLRequest *newRequest = [self.request mutableCopy];
	
	void (^cancelLoading)(void) = ^(void) {
		/* need to continue the chain with a blank response so downstream knows we're done */
		[self.client URLProtocol:self didReceiveResponse:[[NSURLResponse alloc] init] cacheStoragePolicy:NSURLCacheStorageNotAllowed];
		[self.client URLProtocolDidFinishLoading:self];
	};
	
	NSString *wvthash = [NSURLProtocol propertyForKey:@"WebViewTab" inRequest:newRequest];
	if (wvthash != nil && ![wvthash isEqualToString:@""]) {
		for (WebViewTab *_wvt in [[appDelegate webViewController] webViewTabs]) {
			if ([[NSString stringWithFormat:@"%lu", (unsigned long)[_wvt hash]] isEqualToString:wvthash]) {
				wvt = _wvt;
				break;
			}
		}
	}
	
	if (wvt == nil) {
		/* make a best attempt at finding the tab by this request's same maindocument */
		for (WebViewTab *_wvt in [[appDelegate webViewController] webViewTabs]) {
			if ([[[newRequest mainDocumentURL] absoluteString] isEqualToString:[[_wvt url] absoluteString]]) {
				if (wvt == nil) {
					wvt = _wvt;
				}
				else {
					NSLog(@"[URLInterceptor] request for %@ matched two tabs (%@ and %@)", newRequest, [wvt tabNumber], [_wvt tabNumber]);
					wvt = nil;
					break;
				}
			}
		}
	}
	
	if (wvt == nil) {
		NSLog(@"[URLInterceptor] request for %@ with no matching WebViewTab! (main URL %@)", [newRequest URL], [newRequest mainDocumentURL]);
		cancelLoading();
		return;
	}
	
	if (![NSURLProtocol propertyForKey:ORIGIN_KEY inRequest:newRequest]) {
		if ([URLBlocker shouldBlockURL:[newRequest URL]]) {
			cancelLoading();
			return;
		}
	}
	
#ifdef TRACE
	NSLog(@"[Tab %@] initializing with %@ request: %@", wvt.tabNumber, [newRequest HTTPMethod], [[newRequest URL] absoluteString]);
#endif

	NSArray *HTErules = [HTTPSEverywhere potentiallyApplicableRulesForHost:[[[self request] URL] host]];
	if (HTErules != nil && [HTErules count] > 0) {
		[newRequest setURL:[HTTPSEverywhere rewrittenURI:[[self request] URL] withRules:HTErules]];
		
		for (HTTPSEverywhereRule *HTErule in HTErules) {
			[[wvt applicableHTTPSEverywhereRules] setObject:@YES forKey:[HTErule name]];
		}
	}
	
	if (![NSURLProtocol propertyForKey:ORIGIN_KEY inRequest:newRequest]) {
		if ([wvt secureMode] > WebViewTabSecureModeInsecure && ![[[[newRequest URL] scheme] lowercaseString] isEqualToString:@"https"]) {
			[wvt setSecureMode:WebViewTabSecureModeMixed];
			NSLog(@"[Tab %@] blocking mixed-content request %@", wvt.tabNumber, [newRequest URL]);
			cancelLoading();
			return;
		}
	}
	
	/* redirections can happen without us seeing them, so keep the webview chrome in the loop */
	[wvt setUrl:[newRequest mainDocumentURL]];
	[[appDelegate webViewController] performSelectorOnMainThread:@selector(updateSearchBarDetails) withObject:nil waitUntilDone:NO];
	
	/* we're handling cookies ourself */
	[newRequest setHTTPShouldHandleCookies:NO];
	NSArray *cookies = [[appDelegate cookieStorage] cookiesForURL:[newRequest URL]];
	if (cookies != nil && [cookies count] > 0) {
#ifdef TRACE
		NSLog(@"[Tab %@] sending %lu cookie(s) to %@", wvt.tabNumber, [cookies count], [newRequest URL]);
#endif
		NSDictionary *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
		[newRequest setAllHTTPHeaderFields:headers];
	}
	
	/* add "do not track" header if it's enabled in the settings */
	if (sendDNT)
		[newRequest setValue:@"1" forHTTPHeaderField:@"DNT"];

	/* remember that we saw this to avoid a loop */
	[NSURLProtocol setProperty:@YES forKey:REWRITTEN_KEY inRequest:newRequest];

	self.connection = [NSURLConnection connectionWithRequest:newRequest delegate:self];
}

- (void)stopLoading
{
	[self.connection cancel];
}

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
	BOOL schemaRedirect = false;
	
	/* we don't get a redirectResponse when only upgrading from http -> https on the same hostname, so we have to find it ourselves :( */
	if (response == nil && [self.origRequest hash] != [request hash]) {
#ifdef TRACE
		NSLog(@"[Tab %@] hash changed, URL went from %@ to %@", wvt.tabNumber, [[self.origRequest URL] absoluteString], [[request URL] absoluteString]);
#endif
		schemaRedirect = true;
	}
	
	if (response != nil || schemaRedirect) {
		[self extractCookiesFromResponse:response forURL:[request URL] fromMainDocument:[wvt url]];

		if (schemaRedirect && response == nil) {
#ifdef TRACE
			NSLog(@"[Tab %@] willSendRequest being redirected (schema-only) from %@ to %@", wvt.tabNumber, [[self.origRequest URL] absoluteString], [[request URL] absoluteString]);
#endif
			if ([[[self.origRequest URL] scheme] isEqualToString:@"https"] && [[[request URL] scheme] isEqualToString:@"http"]) {
				[HTTPSEverywhere noteInsecureRedirectionForURL:[self.origRequest URL]];
			}
		}
		else {
#ifdef TRACE
			NSLog(@"[Tab %@] willSendRequest being redirected from %@ to %@", wvt.tabNumber, [[response URL] absoluteString], [[request URL] absoluteString]);
#endif
			if ([[[response URL] scheme] isEqualToString:@"https"] && [[[request URL] scheme] isEqualToString:@"http"]) {
				[HTTPSEverywhere noteInsecureRedirectionForURL:[request URL]];
			}
		}
		
		NSMutableURLRequest *redirectRequest = [request mutableCopy];
		
		/* so we process it again */
		[[self class] removePropertyForKey:REWRITTEN_KEY inRequest:redirectRequest];
		[[self client] URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:response];
		
		[self.connection cancel];
		[[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
		
		return redirectRequest;
	}
	
	return request;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self extractCookiesFromResponse:response forURL:[self.request URL] fromMainDocument:[wvt url]];
	
	if ([NSURLProtocol propertyForKey:ORIGIN_KEY inRequest:self.request]) {
		if ([[[[self.request URL] scheme] lowercaseString] isEqualToString:@"https"]) {
			/* initial request was over https, start considering us secure */
		
			if (self.evOrgName != nil && ![self.evOrgName isEqualToString:@""]) {
				[wvt setSecureMode:WebViewTabSecureModeSecureEV];
				[wvt setEvOrgName:self.evOrgName];
			} else
				[wvt setSecureMode:WebViewTabSecureModeSecure];
		}
	}
	else if ([wvt secureMode] > WebViewTabSecureModeInsecure && ![[[[self.request URL] scheme] lowercaseString] isEqualToString:@"https"]) {
		/* an element on the page was not sent over https but the initial request was, downgrade to mixed */
		if ([wvt secureMode] > WebViewTabSecureModeInsecure)
			[wvt setSecureMode:WebViewTabSecureModeMixed];
	}
	
	[self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[self.client URLProtocol:self didLoadData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	[self.client URLProtocol:self didFailWithError:error];
	[self.connection cancel];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self.client URLProtocolDidFinishLoading:self];
	self.connection = nil;
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace
{
	return [[protectionSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void) connection:(NSURLConnection *)conn didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
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
		NSLog(@"[Tab %@] cert for %@ has EV, registered to %@", wvt.tabNumber, [[self.request URL] host], orgname);
#endif
		if ([NSURLProtocol propertyForKey:ORIGIN_KEY inRequest:self.request] && [[[[self.request URL] host] lowercaseString] isEqualToString:[[[wvt url] host] lowercaseString]])
			[self setEvOrgName:orgname];
	}

	/* TODO: check for blacklisted certs or CAs? */
	// [[challenge sender] cancelAuthenticationChallenge:challenge];
	
	[[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)extractCookiesFromResponse:(NSURLResponse *)response forURL:(NSURL *)url fromMainDocument:(NSURL *)mainDocument
{
	NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
	NSMutableArray *cookies = [[NSMutableArray alloc] initWithCapacity:5];
	
	for (NSHTTPCookie *cookie in [NSHTTPCookie cookiesWithResponseHeaderFields:[httpResponse allHeaderFields] forURL:url]) {
		NSMutableDictionary *ps = (NSMutableDictionary *)[cookie properties];
		
		if (![cookie isSecure] && [HTTPSEverywhere needsSecureCookieFromHost:[url host] forHost:[cookie domain] cookieName:[cookie name]]) {
			/* toggle "secure" bit */
			[ps setValue:@"TRUE" forKey:NSHTTPCookieSecure];
		}
		
		if (![[appDelegate cookieWhitelist] isHostWhitelisted:[url host]]) {
			/* host isn't whitelisted, force to a session cookie */
			[ps setValue:@"TRUE" forKey:NSHTTPCookieDiscard];
		}
		
		NSHTTPCookie *nCookie = [[NSHTTPCookie alloc] initWithProperties:ps];
		[cookies addObject:nCookie];
	}
	
	if ([cookies count] > 0) {
#ifdef TRACE
		NSLog(@"[Tab %@] storing %lu cookie(s) for %@ (via %@)", wvt.tabNumber, [cookies count], [url host], mainDocument);
#endif
		[[appDelegate cookieStorage] setCookies:cookies forURL:url mainDocumentURL:mainDocument];
	}
}

@end