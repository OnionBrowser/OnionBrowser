// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

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
