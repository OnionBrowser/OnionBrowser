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

#import <Foundation/Foundation.h>
#import "SSLCertificate.h"

@protocol CKHTTPConnectionDelegate;

@class CKHTTPAuthenticationChallenge;

@interface CKHTTPConnection : NSObject
{
	@private
	__weak id <CKHTTPConnectionDelegate> _delegate;

	CFHTTPMessageRef _HTTPRequest;
	NSInputStream *_HTTPStream;
	NSInputStream *_HTTPBodyStream;
	BOOL _haveReceivedResponse;
	CKHTTPAuthenticationChallenge *_authenticationChallenge;
	NSInteger _authenticationAttempts;
	
	BOOL socketReady;
	BOOL retriedSocket;
}

+ (CKHTTPConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id <CKHTTPConnectionDelegate>)delegate;
- (id)initWithRequest:(NSURLRequest *)request delegate:(id <CKHTTPConnectionDelegate>)delegate;
- (void)cancel;

@end


@protocol CKHTTPConnectionDelegate

- (void)HTTPConnection:(CKHTTPConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (void)HTTPConnection:(CKHTTPConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;

- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response;
- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveData:(NSData *)data;

- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveSecTrust:(SecTrustRef)secTrustRef certificate:(SSLCertificate *)certificate;

- (void)HTTPConnectionDidFinishLoading:(CKHTTPConnection *)connection;
- (void)HTTPConnection:(CKHTTPConnection *)connection didFailWithError:(NSError *)error;

@end


@interface NSURLRequest (CKHTTPURLRequest)
- (CFHTTPMessageRef)makeHTTPMessage;
@end
