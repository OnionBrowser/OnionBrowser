#import "AppDelegate.h"
#import "HTTPSEverywhere.h"
#import "URLBlocker.h"
#import "URLInterceptor.h"
#import "WebViewTab.h"

@interface URLInterceptor ()
@property (nonatomic, strong) NSURLConnection *connection;
@end

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
	self.origRequest = self.request;

	NSMutableURLRequest *newRequest = [self.request mutableCopy];
	
	NSString *wvthash = (NSString *)[NSURLProtocol propertyForKey:@"WebViewTab" inRequest:newRequest];
	if (wvthash != nil && ![wvthash isEqualToString:@""]) {
		for (WebViewTab *_wvt in [[appDelegate webViewController] webViewTabs]) {
			if ([[NSString stringWithFormat:@"%lu", (unsigned long)[_wvt hash]] isEqualToString:wvthash]) {
				wvt = _wvt;
				break;
			}
		}
	}
	
	if (wvt == nil) {
		NSLog(@"request for %@ with no matching WebViewTab!", [newRequest URL]);
		self.connection = nil;
		return;
	}
	
	if (![NSURLProtocol propertyForKey:ORIGIN_KEY inRequest:newRequest]) {
		if ([URLBlocker shouldBlockURL:[newRequest URL]]) {
			/* need to continue the chain with a blank response so downstream knows we're done */
			[self.client URLProtocol:self didReceiveResponse:[[NSURLResponse alloc] init] cacheStoragePolicy:NSURLCacheStorageNotAllowed];
			[self.client URLProtocolDidFinishLoading:self];
			return;
		}
		
		/* we need to catch these here in the case of http -> https redirections */
		if ([wvt secureMode] > WebViewTabSecureModeInsecure && ![[[[self.request URL] scheme] lowercaseString] isEqualToString:@"https"])
			[wvt setSecureMode:WebViewTabSecureModeMixed];
	}

#ifdef TRACE
	NSLog(@"[Tab %@] startLoading URL (%@): %@", wvt.tabNumber, [newRequest HTTPMethod], [[newRequest URL] absoluteString]);
#endif
	
	[newRequest setURL:[HTTPSEverywhere rewrittenURI:[[self request] URL]]];
	
	/* redirections can happen without us seeing them, so keep the webview chrome in the loop */
	[wvt setUrl:[newRequest mainDocumentURL]];
	[[wvt controller] performSelectorOnMainThread:@selector(updateSearchBarDetails) withObject:nil waitUntilDone:NO];
	
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
	
	/* we don't get a redirect response when only upgrading from http -> https on the same hostname, so we have to find it ourselves :( */
	if (response == nil && [self.origRequest hash] != [request hash]) {
#ifdef TRACE
		NSLog(@"[Tab %@] hash changed, URL went from %@ to %@", wvt.tabNumber, [[self.origRequest URL] absoluteString], [[request URL] absoluteString]);
#endif
		schemaRedirect = true;
	}
	
	if (response == nil && !schemaRedirect) {
#ifdef TRACE
		NSLog(@"[Tab %@] willSendRequest %@ to %@", wvt.tabNumber, [request HTTPMethod], [[request URL] absoluteString]);
#endif
	}
	else {
		[self extractCookiesFromResponse:response forURL:[request URL] fromMainDocument:[wvt url]];

#ifdef TRACE
		if (schemaRedirect && response == nil)
			NSLog(@"[Tab %@] willSendRequest being redirected (schema-only) from %@ to %@", wvt.tabNumber, [[self.origRequest URL] absoluteString], [[request URL] absoluteString]);
		else
			NSLog(@"[Tab %@] willSendRequest being redirected from %@ to %@", wvt.tabNumber, [[response URL] absoluteString], [[request URL] absoluteString]);
#endif
		
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
		/* toggle "secure" bit */
		NSMutableDictionary *ps = (NSMutableDictionary *)[cookie properties];
		[ps setValue:@"TRUE" forKey:NSHTTPCookieSecure];
		
		/* and make everything a session cookie */
		[ps setValue:@"TRUE" forKey:NSHTTPCookieDiscard];
		
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