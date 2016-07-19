//
//  TorProxyURLProtocol.h
//
//  Onion Browser fork by Mike Tigas
//  Copyright 2012-2016 Mike Tigas. All rights reserved.
//  https://github.com/OnionBrowser/iOS-OnionBrowser/blob/master/LICENSE
//
//  Created by Rob Napier on 11/30/07.
//  Copyright 2007. All rights reserved.

#import "CKHTTPConnection.h"

#define PROXY_CONTENT_HTML 0
#define PROXY_CONTENT_JS 1
#define PROXY_CONTENT_OTHER 2

@interface TorProxyURLProtocol : NSURLProtocol <CKHTTPConnectionDelegate> {
    NSURLRequest *_request;
    CKHTTPConnection *_connection;
    NSMutableData *_data;
    Boolean isGzippedResponse;

    NSUInteger incomingContentType;
    Boolean firstChunk;
}

- (NSMutableData *)data;

@end
