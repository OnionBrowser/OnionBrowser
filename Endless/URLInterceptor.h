#import <Foundation/Foundation.h>

#define REWRITTEN_KEY @"_rewritten"
#define ORIGIN_KEY @"_origin"

@interface URLInterceptor : NSURLProtocol <NSURLProtocolClient, NSURLConnectionDataDelegate>

@property (strong) NSURLRequest *origRequest;
@property (assign) BOOL isOrigin;
@property (strong) NSString *evOrgName;
@property (strong) NSURLConnection *connection;

+ (void)setBlockIntoLocalNets:(BOOL)val;
+ (void)setSendDNT:(BOOL)val;
+ (void)temporarilyAllow:(NSURL *)url;

@end
