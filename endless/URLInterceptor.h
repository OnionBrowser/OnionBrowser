#import <Foundation/Foundation.h>

@interface URLInterceptor : NSURLProtocol <NSURLProtocolClient, NSURLConnectionDataDelegate>

@property (strong, nonatomic) NSURLRequest *origRequest;
@property (strong, nonatomic) NSString *evOrgName;

@end
