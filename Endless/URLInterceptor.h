/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>
#import "CKHTTPConnection.h"
#import "HostSettings.h"

#define REWRITTEN_KEY @"_rewritten"
#define ORIGIN_KEY @"_origin"
#define WVT_KEY @"_wvt"

#define CONTENT_TYPE_OTHER	0
#define CONTENT_TYPE_HTML	1

#define ENCODING_DEFLATE	1
#define ENCODING_GZIP		2

@interface URLInterceptor : NSURLProtocol <CKHTTPConnectionDelegate> {
	NSMutableData *_data;
	NSURLRequest *_request;
	NSUInteger encoding;
	NSUInteger contentType;
	Boolean firstChunk;
}

@property (strong) NSURLRequest *actualRequest;
@property (assign) BOOL isOrigin;
@property (strong) NSString *evOrgName;
@property (strong) CKHTTPConnection *connection;
@property (strong) HostSettings *hostSettings;
@property (strong) HostSettings *originHostSettings;
@property (strong, nonatomic) NSString *cspNonce;

+ (void)setup;
+ (void)clearInjectCache;
+ (NSString *)javascriptToInject;
+ (void)setSendDNT:(BOOL)val;
+ (void)temporarilyAllow:(NSURL *)url;
+ (NSString *)prependDirectivesIfExisting:(NSDictionary *)directives inCSPHeader:(NSString *)header;

- (NSMutableData *)data;

@end

#ifdef USE_DUMMY_URLINTERCEPTOR
@interface DummyURLInterceptor : NSURLProtocol
@property (nonatomic, strong) NSURLConnection *connection;
@property (assign) BOOL isOrigin;
@end
#endif
