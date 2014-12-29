#import <Foundation/Foundation.h>

#define REWRITTEN_KEY @"_rewritten"
#define ORIGIN_KEY @"_origin"

@interface URLInterceptor : NSURLProtocol <NSURLProtocolClient, NSURLConnectionDataDelegate>

@property (strong) NSURLRequest *origRequest;
@property (strong) NSString *evOrgName;
@property (strong) NSURLConnection *connection;

+ (void)setSendDNT:(BOOL)val;

@end
