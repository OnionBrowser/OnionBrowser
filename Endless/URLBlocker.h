#import <Foundation/Foundation.h>

@interface URLBlocker : NSObject

+ (NSDictionary *)targets;

+ (BOOL)shouldBlockURL:(NSURL *)url;

@end
