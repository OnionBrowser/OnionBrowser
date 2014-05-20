//
//  ProxyURLProtocol.h
//  PandoraBoy
//
//  Created by Rob Napier on 11/30/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//
// Special NSURLProtocol to capture information out of the stream.
// It does very little; most work is done by subclasses

#import "CKHTTPConnection.h"

#define PROXY_CONTENT_HTML 0
#define PROXY_CONTENT_JS 1
#define PROXY_CONTENT_OTHER 2

@interface ProxyURLProtocol : NSURLProtocol <CKHTTPConnectionDelegate, UIAlertViewDelegate> {
    NSURLRequest *_request;
    CKHTTPConnection *_connection;
    NSMutableData *_data;
    Boolean isGzippedResponse;

    NSUInteger incomingContentType;
    Boolean firstChunk;
}

- (NSMutableData *)data;

- (NSData *)htmlDataWithJavascriptInjection:incomingData;
- (NSData *)javascriptDataWithJavascriptInjection:incomingData;

@end
