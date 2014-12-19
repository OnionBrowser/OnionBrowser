#import <Foundation/Foundation.h>

#define REWRITTEN_KEY @"_rewritten"
#define ORIGIN_KEY @"_origin"

@interface URLInterceptor : NSURLProtocol <NSURLProtocolClient, NSURLConnectionDataDelegate>

@property (strong, nonatomic) NSURLRequest *origRequest;
@property (strong, nonatomic) NSString *evOrgName;
@property (nonatomic, strong) NSURLConnection *connection;

+ (void)setSendDNT:(BOOL)val;

@end
