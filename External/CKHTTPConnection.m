/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * Originally created by Mike Abdullah on 17/03/2009.
 * Copyright 2009 Karelia Software. All rights reserved.
 *
 * Originally from ConnectionKit 2.0 branch; source at:
 * http://www.opensource.utr-software.com/source/connection/branches/2.0/CKHTTPConnection.m
 * (CKHTTPConnection.m last updated rev 1242, 2009-06-16 09:40:21 -0700, by mabdullah)
 *
 * Under Modified BSD License, as per description at
 * http://www.opensource.utr-software.com/
 */

#import "CKHTTPConnection.h"
#import "HostSettings.h"
#import "SSLCertificate.h"

// There is no public API for creating an NSHTTPURLResponse. The only way to create one then, is to
// have a private subclass that others treat like a standard NSHTTPURLResponse object. Framework
// code can instantiate a CKHTTPURLResponse object directly. Alternatively, there is a public
// convenience method +[NSHTTPURLResponse responseWithURL:HTTPMessage:]


@interface CKHTTPURLResponse : NSHTTPURLResponse
{
	@private
	NSInteger _statusCode;
	NSDictionary *_headerFields;
}

- (id)initWithURL:(NSURL *)URL HTTPMessage:(CFHTTPMessageRef)message;

@end


@interface CKHTTPAuthenticationChallenge : NSURLAuthenticationChallenge
{
	CFHTTPAuthenticationRef _HTTPAuthentication;
}

- (id)initWithResponse:(CFHTTPMessageRef)response
    proposedCredential:(NSURLCredential *)credential
  previousFailureCount:(NSInteger)failureCount
       failureResponse:(NSHTTPURLResponse *)URLResponse
                sender:(id <NSURLAuthenticationChallengeSender>)sender;

- (CFHTTPAuthenticationRef)CFHTTPAuthentication;

@end


@interface CKHTTPConnection ()
- (CFHTTPMessageRef)HTTPRequest;
- (NSInputStream *)HTTPStream;

- (void)start;
- (id <CKHTTPConnectionDelegate>)delegate;
@end


@interface CKHTTPConnection (Authentication) <NSURLAuthenticationChallengeSender>
- (CKHTTPAuthenticationChallenge *)currentAuthenticationChallenge;
@end


#pragma mark -

@implementation CKHTTPConnection

#pragma mark  Init & Dealloc

+ (CKHTTPConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id <CKHTTPConnectionDelegate>)delegate
{
	return [[self alloc] initWithRequest:request delegate:delegate];
}

- (id)initWithRequest:(NSURLRequest *)request delegate:(id <CKHTTPConnectionDelegate>)delegate;
{
	NSParameterAssert(request);

	if (self = [super init]) {
		_delegate = delegate;

		// Kick off the connection
		_HTTPRequest = [request makeHTTPMessage];

		[self start];
	}

	return self;
}

- (void)dealloc
{
	CFRelease(_HTTPRequest);
}

#pragma mark Accessors

- (CFHTTPMessageRef)HTTPRequest {
	return _HTTPRequest;
}

- (NSInputStream *)HTTPStream {
	return _HTTPStream;
}

- (NSInputStream *)stream {
	return (NSInputStream *)[self HTTPStream];
}

- (id <CKHTTPConnectionDelegate>)delegate {
	return _delegate;
}

#pragma mark Status handling

- (void)start
{
	NSAssert(!_HTTPStream, @"Connection already started");
	HostSettings *hs;
	
	_HTTPStream = (__bridge_transfer NSInputStream *)CFReadStreamCreateForHTTPRequest(NULL, [self HTTPRequest]);
	
	/* we're handling redirects ourselves */
	CFReadStreamSetProperty((__bridge CFReadStreamRef)(_HTTPStream), kCFStreamPropertyHTTPShouldAutoredirect, kCFBooleanFalse);

	NSString *method = (__bridge_transfer NSString *)CFHTTPMessageCopyRequestMethod([self HTTPRequest]);
	if ([[method uppercaseString] isEqualToString:@"GET"])
		CFReadStreamSetProperty((__bridge CFReadStreamRef)(_HTTPStream), kCFStreamPropertyHTTPAttemptPersistentConnection, kCFBooleanTrue);
	else
		CFReadStreamSetProperty((__bridge CFReadStreamRef)(_HTTPStream), kCFStreamPropertyHTTPAttemptPersistentConnection, kCFBooleanFalse);
	
	/* set SSL protocol version enforcement before opening, when using kCFStreamSSLLevel */
	NSURL *url = (__bridge_transfer NSURL *)(CFHTTPMessageCopyRequestURL([self HTTPRequest]));
	if ([[[url scheme] lowercaseString] isEqualToString:@"https"]) {
		hs = [HostSettings settingsOrDefaultsForHost:[url host]];
		
		if ([[hs settingOrDefault:HOST_SETTINGS_KEY_TLS] isEqualToString:HOST_SETTINGS_TLS_12]) {
			/* kTLSProtocol12 allows lower protocols, so use kCFStreamSSLLevel to force 1.2 */
			
			CFMutableDictionaryRef sslOptions = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
			CFDictionarySetValue(sslOptions, kCFStreamSSLLevel, CFSTR("kCFStreamSocketSecurityLevelTLSv1_2"));
			CFReadStreamSetProperty((__bridge CFReadStreamRef)_HTTPStream, kCFStreamPropertySSLSettings, sslOptions);
			
#ifdef TRACE_HOST_SETTINGS
			NSLog(@"[HostSettings] set TLS/SSL min level for %@ to TLS 1.2", [url host]);
#endif
		}
	}
	
	[_HTTPStream setDelegate:(id<NSStreamDelegate>)self];
	[_HTTPStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
	[_HTTPStream open];

	/* for other SSL options, these need an SSLContextRef which doesn't exist until the stream is opened */
	if ([[[url scheme] lowercaseString] isEqualToString:@"https"]) {
		SSLContextRef sslContext = (__bridge SSLContextRef)[_HTTPStream propertyForKey:(__bridge NSString *)kCFStreamPropertySSLContext];
		if (sslContext != NULL) {
			SSLSessionState sslState;
			SSLGetSessionState(sslContext, &sslState);
			
			/* if we're not idle, this is probably a persistent connection we already opened and negotiated */
			if (sslState == kSSLIdle) {
				if (![self disableWeakSSLCiphers:sslContext]) {
					NSLog(@"[CKHTTPConnection] failed disabling weak ciphers, aborting connection");
					[self _cancelStream];
					return;
				}
			}
		}
	}
}

- (BOOL)disableWeakSSLCiphers:(SSLContextRef)sslContext
{
	OSStatus status;
	size_t numSupported;
	SSLCipherSuite *supported = NULL;
	SSLCipherSuite *enabled = NULL;
	int numEnabled = 0;
	
	status = SSLGetNumberSupportedCiphers(sslContext, &numSupported);
	if (status != noErr) {
		NSLog(@"[CKHTTPConnection] failed getting number of supported ciphers");
		return NO;
	}
	
	supported = (SSLCipherSuite *)malloc(numSupported * sizeof(SSLCipherSuite));
	status = SSLGetSupportedCiphers(sslContext, supported, &numSupported);
	if (status != noErr) {
		NSLog(@"[CKHTTPConnection] failed getting supported ciphers");
		free(supported);
		return NO;
	}
	
	enabled = (SSLCipherSuite *)malloc(numSupported * sizeof(SSLCipherSuite));
	
	/* XXX: should we reverse this and only ban bad ciphers and allow all others? */
	for (int i = 0; i < numSupported; i++) {
		switch (supported[i]) {
		case TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256:
		case TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256:
		case TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA:
		case TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA:
		case TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA:
		case TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA:
		case TLS_DHE_RSA_WITH_AES_128_CBC_SHA:
		case TLS_DHE_RSA_WITH_AES_256_CBC_SHA:
		case TLS_RSA_WITH_AES_128_CBC_SHA:
		case TLS_RSA_WITH_AES_256_CBC_SHA:
		case TLS_RSA_WITH_3DES_EDE_CBC_SHA:
			enabled[numEnabled++] = supported[i];
			break;
		}
	}
	free(supported);

	status = SSLSetEnabledCiphers(sslContext, enabled, numEnabled);
	free(enabled);
	if (status != noErr) {
		NSLog(@"[CKHTTPConnection] failed setting enabled ciphers on %@: %d", sslContext, (int)status);
		return NO;
	}
	
	return YES;
}

- (void)_cancelStream
{
	// Support method to cancel the HTTP stream, but not change the delegate. Used for:
	//  A) Cancelling the connection
	//  B) Waiting to restart the connection while authentication takes place
	//  C) Restarting the connection after an HTTP redirect
	[_HTTPStream close];
	CFBridgingRelease((__bridge_retained CFTypeRef)(_HTTPStream));
	//[_HTTPStream release]; 
	_HTTPStream = nil;
}

- (void)cancel
{
	// Cancel the stream and stop the delegate receiving any more info
	[self _cancelStream];
	_delegate = nil;
}

- (void)stream:(NSInputStream *)theStream handleEvent:(NSStreamEvent)streamEvent
{
	NSParameterAssert(theStream == [self stream]);
	
	NSURL *URL = [theStream propertyForKey:(NSString *)kCFStreamPropertyHTTPFinalURL];

	if (!_haveReceivedResponse) {
		CFHTTPMessageRef response = (__bridge CFHTTPMessageRef)[theStream propertyForKey:(NSString *)kCFStreamPropertyHTTPResponseHeader];
		if (response && CFHTTPMessageIsHeaderComplete(response)) {
			NSHTTPURLResponse *URLResponse = [NSHTTPURLResponse responseWithURL:URL HTTPMessage:response];
			
			/* work around bug where CFHTTPMessageIsHeaderComplete reports true but there is no actual header data to be found */
			if ([URLResponse statusCode] == 200 && [URLResponse expectedContentLength] == 0 && [[URLResponse allHeaderFields] count] == 0) {
#ifdef TRACE
				NSLog(@"[CKHTTPConnection] hit CFHTTPMessageIsHeaderComplete bug, waiting for more data");
#endif
				goto process;
			}
			
			// If the response was an authentication failure, try to request fresh credentials.
			if ([URLResponse statusCode] == 401 || [URLResponse statusCode] == 407) {
				// Cancel any further loading and ask the delegate for authentication
				[self _cancelStream];
				
				NSAssert(![self currentAuthenticationChallenge], @"Authentication challenge received while another is in progress");
				
				_authenticationChallenge = [[CKHTTPAuthenticationChallenge alloc] initWithResponse:response proposedCredential:nil previousFailureCount:_authenticationAttempts failureResponse:URLResponse sender:self];
				
				if ([self currentAuthenticationChallenge]) {
					_authenticationAttempts++;
					[[self delegate] HTTPConnection:self didReceiveAuthenticationChallenge:[self currentAuthenticationChallenge]];
					return; // Stops the delegate being sent a response received message
				}
			}
			
			// By reaching this point, the response was not a valid request for authentication,
			// so go ahead and report it
			_haveReceivedResponse = YES;
			[[self delegate] HTTPConnection:self didReceiveResponse:URLResponse];
		}
	}
	
process:
	switch (streamEvent) {
	case NSStreamEventHasSpaceAvailable:
		socketReady = true;
		break;
	case NSStreamEventErrorOccurred:
		if (!socketReady && !retriedSocket) {
			/* probably a dead keep-alive socket from the get go */
			retriedSocket = true;
			NSLog(@"[CKHTTPConnection] socket for %@ dead but never writable, retrying (%@)", [URL absoluteString], [theStream streamError]);
			[self _cancelStream];
			[self start];
		}
		else
			[[self delegate] HTTPConnection:self didFailWithError:[theStream streamError]];
		break;

	case NSStreamEventEndEncountered:   // Report the end of the stream to the delegate
		[[self delegate] HTTPConnectionDidFinishLoading:self];
		break;

	case NSStreamEventHasBytesAvailable: {
		socketReady = true;
		
		if ([[[URL scheme] lowercaseString] isEqualToString:@"https"]) {
			SecTrustRef trust = (__bridge SecTrustRef)[theStream propertyForKey:(__bridge NSString *)kCFStreamPropertySSLPeerTrust];
			if (trust != nil) {
				SSLCertificate *cert = [[SSLCertificate alloc] initWithSecTrustRef:trust];
				
				SSLContextRef sslContext = (__bridge SSLContextRef)[theStream propertyForKey:(__bridge NSString *)kCFStreamPropertySSLContext];
				SSLProtocol proto;
				SSLGetNegotiatedProtocolVersion(sslContext, &proto);
				[cert setNegotiatedProtocol:proto];
				
				SSLCipherSuite cipher;
				SSLGetNegotiatedCipher(sslContext, &cipher);
				[cert setNegotiatedCipher:cipher];
				
				[[self delegate] HTTPConnection:self didReceiveSecTrust:trust certificate:cert];
			}
		}
		
		NSMutableData *data = [[NSMutableData alloc] initWithCapacity:1024];
		while ([theStream hasBytesAvailable]) {
			uint8_t buf[1024];
			NSUInteger len = [theStream read:buf maxLength:1024];
			[data appendBytes:(const void *)buf length:len];
		}

		[[self delegate] HTTPConnection:self didReceiveData:data];
		
		break;
	}
	default:
		break;
	}
}

@end


#pragma mark -


@implementation CKHTTPConnection (Authentication)

- (CKHTTPAuthenticationChallenge *)currentAuthenticationChallenge {
	return _authenticationChallenge;
}

- (void)_finishCurrentAuthenticationChallenge
{
	_authenticationChallenge = nil;
}

- (void)useCredential:(NSURLCredential *)credential forAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	NSParameterAssert(challenge == [self currentAuthenticationChallenge]);
	[self _finishCurrentAuthenticationChallenge];

	// Retry the request, this time with authentication
	// TODO: What if this function fails?
	CFHTTPAuthenticationRef HTTPAuthentication = [(CKHTTPAuthenticationChallenge *)challenge CFHTTPAuthentication];
	CFHTTPMessageApplyCredentials([self HTTPRequest], HTTPAuthentication, (__bridge CFStringRef)[credential user], (__bridge CFStringRef)[credential password], NULL);
	[self start];
}

- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	NSParameterAssert(challenge == [self currentAuthenticationChallenge]);
	[self _finishCurrentAuthenticationChallenge];

	// Just return the authentication response to the delegate
	[[self delegate] HTTPConnection:self didReceiveResponse:(NSHTTPURLResponse *)[challenge failureResponse]];
	[[self delegate] HTTPConnectionDidFinishLoading:self];
}

- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{
	NSParameterAssert(challenge == [self currentAuthenticationChallenge]);
	[self _finishCurrentAuthenticationChallenge];

	// Treat like a -cancel message
	[self cancel];
}

@end


#pragma mark -


@implementation NSURLRequest (CKHTTPURLRequest)

- (CFHTTPMessageRef)makeHTTPMessage
{
	CFHTTPMessageRef result = CFHTTPMessageCreateRequest(NULL, (__bridge CFStringRef)[self HTTPMethod], (__bridge CFURLRef)[self URL], kCFHTTPVersion1_1);
	
	CFHTTPMessageSetHeaderFieldValue(result, (__bridge CFStringRef)@"Accept-Encoding", (__bridge CFStringRef)@"gzip, deflate");
	
	if ([[[self HTTPMethod] uppercaseString] isEqualToString:@"GET"])
		CFHTTPMessageSetHeaderFieldValue(result, (__bridge CFStringRef)@"Connection", (__bridge CFStringRef)@"keep-alive");
	else
		CFHTTPMessageSetHeaderFieldValue(result, (__bridge CFStringRef)@"Connection", (__bridge CFStringRef)@"close");

	for (NSString *hf in [self allHTTPHeaderFields])
		CFHTTPMessageSetHeaderFieldValue(result, (__bridge CFStringRef)hf, (__bridge CFStringRef)[[self allHTTPHeaderFields] objectForKey:hf]);

	NSData *body = [self HTTPBody];
	if (body)
		CFHTTPMessageSetBody(result, (__bridge CFDataRef)body);
	
	return result;
}

@end


#pragma mark -


@implementation NSHTTPURLResponse (CKHTTPConnectionAdditions)

+ (NSHTTPURLResponse *)responseWithURL:(NSURL *)URL HTTPMessage:(CFHTTPMessageRef)message
{
	return [[CKHTTPURLResponse alloc] initWithURL:URL HTTPMessage:message];
}

@end


@implementation CKHTTPURLResponse

- (id)initWithURL:(NSURL *)URL HTTPMessage:(CFHTTPMessageRef)message
{
	_headerFields = (__bridge_transfer NSDictionary *)CFHTTPMessageCopyAllHeaderFields(message);

	NSString *MIMEType = [_headerFields objectForKey:@"Content-Type"];
	NSInteger contentLength = [[_headerFields objectForKey:@"Content-Length"] intValue];
	NSString *encoding = [_headerFields objectForKey:@"Content-Encoding"];

	if (self = [super initWithURL:URL MIMEType:MIMEType expectedContentLength:contentLength textEncodingName:encoding])
		_statusCode = CFHTTPMessageGetResponseStatusCode(message);
	
	return self;
}

- (void)dealloc {
	CFRelease((__bridge_retained CFTypeRef)_headerFields);
}

- (NSDictionary *)allHeaderFields {
	return _headerFields;
}

- (NSInteger)statusCode {
	return _statusCode;
}

@end


#pragma mark -


@implementation CKHTTPAuthenticationChallenge

/*  Returns nil if the ref is not suitable
 */
- (id)initWithResponse:(CFHTTPMessageRef)response
    proposedCredential:(NSURLCredential *)credential
  previousFailureCount:(NSInteger)failureCount
       failureResponse:(NSHTTPURLResponse *)URLResponse
                sender:(id <NSURLAuthenticationChallengeSender>)sender
{
	NSParameterAssert(response);
	
#warning "Instance variable used while 'self' is not set to the result of [self init]"
	 
	// Try to create an authentication object from the response
	_HTTPAuthentication = CFHTTPAuthenticationCreateFromResponse(NULL, response);
	if (![self CFHTTPAuthentication])
		return nil;
	
	// NSURLAuthenticationChallenge only handles user and password
	if (!CFHTTPAuthenticationIsValid([self CFHTTPAuthentication], NULL))
		return nil;
	
	if (!CFHTTPAuthenticationRequiresUserNameAndPassword([self CFHTTPAuthentication]))
		return nil;
	
	// Fail if we can't retrieve decent protection space info
	CFArrayRef authenticationDomains = CFHTTPAuthenticationCopyDomains([self CFHTTPAuthentication]);
	NSURL *URL = [(__bridge NSArray *)authenticationDomains lastObject];
	CFRelease(authenticationDomains);

	if (!URL || ![URL host])
		return nil;
	
	// Fail for an unsupported authentication method
	CFStringRef authMethod = CFHTTPAuthenticationCopyMethod([self CFHTTPAuthentication]);
	NSString *authenticationMethod;
	if ([(__bridge NSString *)authMethod isEqualToString:(NSString *)kCFHTTPAuthenticationSchemeBasic])
		authenticationMethod = NSURLAuthenticationMethodHTTPBasic;
	else if ([(__bridge NSString *)authMethod isEqualToString:(NSString *)kCFHTTPAuthenticationSchemeDigest])
		authenticationMethod = NSURLAuthenticationMethodHTTPDigest;
	else {
		CFRelease(authMethod);
		 // unsupported authentication scheme
		return nil;
	}
	CFRelease(authMethod);
	
	// Initialise
	CFStringRef realm = CFHTTPAuthenticationCopyRealm([self CFHTTPAuthentication]);
	
	NSURLProtectionSpace *protectionSpace = [[NSURLProtectionSpace alloc] initWithHost:[URL host]
										  port:([URL port] ? [[URL port] intValue] : 80)
									      protocol:[[URL scheme] lowercaseString]
										 realm:(__bridge NSString *)realm
								  authenticationMethod:authenticationMethod];
	CFRelease(realm);

	self = [self initWithProtectionSpace:protectionSpace
		      proposedCredential:credential
		    previousFailureCount:failureCount
			 failureResponse:URLResponse
				   error:nil
				  sender:sender];
	
	return self;
}

- (void)dealloc
{
	CFRelease(_HTTPAuthentication);
}

- (CFHTTPAuthenticationRef)CFHTTPAuthentication {
	return _HTTPAuthentication;
}

@end
