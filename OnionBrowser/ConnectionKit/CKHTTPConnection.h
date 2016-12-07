// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// This file is derived from "Connection Framework" (ConnectionKit 2.0
// branch), under the Modified BSD License.
// Copyright 2009 Karelia Software. All rights reserved.


//  A sort of NSURLConnection-lite class. Deals purely with HTTP and is not multithreaded
//  internally. Adds the ability to track upload progress.


#import <Foundation/Foundation.h>


@protocol CKHTTPConnectionDelegate;
@class CKHTTPAuthenticationChallenge;


@interface CKHTTPConnection : NSObject
{
    @private
    __weak id <CKHTTPConnectionDelegate>   _delegate;       // weak ref

    CFHTTPMessageRef       _HTTPRequest;
    NSInputStream                   *_HTTPStream;
    NSInputStream                   *_HTTPBodyStream;
    BOOL                            _haveReceivedResponse;
    CKHTTPAuthenticationChallenge   *_authenticationChallenge;
    NSInteger                       _authenticationAttempts;
}

+ (CKHTTPConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id <CKHTTPConnectionDelegate>)delegate;

/*  Any caching instructions will be ignored
 */
- (id)initWithRequest:(NSURLRequest *)request delegate:(id <CKHTTPConnectionDelegate>)delegate;
- (void)cancel;

- (NSUInteger)lengthOfDataSent;

@end


@protocol CKHTTPConnectionDelegate  // Formal protocol for now

- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
- (void)HTTPConnection:(CKHTTPConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;

- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response;
- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveData:(NSData *)data;

- (void)HTTPConnectionDidFinishLoading:(CKHTTPConnection *)connection;
- (void)HTTPConnection:(CKHTTPConnection *)connection didFailWithError:(NSError *)error;

@end


@interface NSURLRequest (CKHTTPURLRequest)
- (CFHTTPMessageRef)makeHTTPMessage;
@end


@interface NSHTTPURLResponse (CKHTTPConnectionAdditions)
+ (NSHTTPURLResponse *)responseWithURL:(NSURL *)URL HTTPMessage:(CFHTTPMessageRef)message;
@end
