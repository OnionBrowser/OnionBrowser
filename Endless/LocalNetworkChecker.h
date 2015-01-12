#import <Foundation/Foundation.h>

@interface LocalNetworkChecker : NSObject

+ (void)clearCache;
+ (BOOL)isHostOnLocalNet:(NSString *)host;

@end
