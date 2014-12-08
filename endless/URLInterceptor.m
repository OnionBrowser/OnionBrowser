#import "AppDelegate.h"
#import "HTTPSEverywhere.h"
#import "URLInterceptor.h"

@interface URLInterceptor ()
@property (nonatomic, strong) NSURLConnection *connection;
@end

@implementation URLInterceptor

#define REWRITTEN_KEY @"_rewritten"

static AppDelegate *appDelegate;

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
	if ([NSURLProtocol propertyForKey:REWRITTEN_KEY inRequest:request] != nil)
		/* already mucked with this request */
		return NO;
	
	if ([[[[request URL] scheme] lowercaseString] isEqualToString:@"data"])
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

- (void)startLoading
{
	self.origRequest = self.request;
	self.evOrgName = nil;

	NSMutableURLRequest *newRequest = [self.request mutableCopy];
	
#ifdef TRACE
	NSLog(@"startLoading URL (%@): %@", [newRequest HTTPMethod], [[newRequest URL] absoluteString]);
#endif
	
	[newRequest setURL:[HTTPSEverywhere rewrittenURI:[[self request] URL]]];
	
	/* redirections can happen without us seeing them, so keep the webview chrome in the loop */
	[[appDelegate curWebView] setCurURL:[newRequest mainDocumentURL]];
	
	/* we're handling cookies ourself */
	[newRequest setHTTPShouldHandleCookies:NO];
	NSArray *cookies = [[appDelegate cookieStorage] cookiesForURL:[newRequest URL]];
	if (cookies != nil && [cookies count] > 0) {
#ifdef TRACE
		NSLog(@"sending %lu cookie(s) to %@", [cookies count], [newRequest URL]);
#endif
		NSDictionary *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
		[newRequest setAllHTTPHeaderFields:headers];
	}
	
	/* add "do not track" header */
	if (true /* TODO: move this to a pref check */) {
		[newRequest setValue:@"1" forHTTPHeaderField:@"DNT"];
	}

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
		NSLog(@"hash changed, URL went from %@ to %@", [[self.origRequest URL] absoluteString], [[request URL] absoluteString]);
#endif
		schemaRedirect = true;
	}
	
	if (response == nil && !schemaRedirect) {
#ifdef TRACE
		NSLog(@"willSendRequest %@ to %@", [request HTTPMethod], [[request URL] absoluteString]);
#endif
	}
	else {
		[self extractCookiesFromResponse:response forURL:[request URL] fromMainDocument:[[appDelegate curWebView] curURL]];

#ifdef TRACE
		if (schemaRedirect && response == nil)
			NSLog(@"willSendRequest being redirected (schema-only) from %@ to %@", [[self.origRequest URL] absoluteString], [[request URL] absoluteString]);
		else
			NSLog(@"willSendRequest being redirected from %@ to %@", [[response URL] absoluteString], [[request URL] absoluteString]);
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
	[self extractCookiesFromResponse:response forURL:[self.request URL] fromMainDocument:[[appDelegate curWebView] curURL]];
		
	if (self.evOrgName != nil && ![self.evOrgName isEqualToString:@""]) {
		NSLog(@"EV info is %@", self.evOrgName);
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
		NSLog(@"cert for %@ has EV, registered to %@", [[self.request URL] host], orgname);
#endif
		if ([[[self.request URL] host] isEqualToString:[[[appDelegate curWebView] curURL] host]])
			[[appDelegate evHosts] setValue:orgname forKey:[[self.request URL] host]];
	}

	/* TODO: check for blacklisted certs or CAs? */
	// [[challenge sender] cancelAuthenticationChallenge:challenge];
	
	[[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)extractCookiesFromResponse:(NSURLResponse *)response forURL:(NSURL *)url fromMainDocument:(NSURL *)mainDocument {
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
		NSLog(@"storing %lu cookie(s) for %@ (via %@)", [cookies count], [url host], mainDocument);
#endif
		[[appDelegate cookieStorage] setCookies:cookies forURL:url mainDocumentURL:mainDocument];
	}
}

@end