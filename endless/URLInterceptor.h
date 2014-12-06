#import <Foundation/Foundation.h>

@interface URLInterceptor : NSURLProtocol <NSURLProtocolClient, NSURLConnectionDataDelegate>

@property (strong, nonatomic) NSURLRequest *origRequest;

@end
