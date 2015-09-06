#import <Foundation/Foundation.h>
#import "CKHTTPConnection.h"
#import "HostSettings.h"

#define REWRITTEN_KEY @"_rewritten"
#define ORIGIN_KEY @"_origin"
#define WVT_KEY @"_wvt"

#define CONTENT_TYPE_OTHER	0
#define CONTENT_TYPE_HTML	1
#define CONTENT_TYPE_JAVASCRIPT	2
#define CONTENT_TYPE_IMAGE	3

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

+ (NSString *)javascriptToInject;
+ (void)setSendDNT:(BOOL)val;
+ (void)temporarilyAllow:(NSURL *)url;

- (NSMutableData *)data;

@end
