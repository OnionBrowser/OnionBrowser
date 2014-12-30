#import <Foundation/Foundation.h>

@interface URLBlocker : NSObject

+ (NSDictionary *)targets;

+ (BOOL)shouldBlockURL:(NSURL *)url;
+ (BOOL)shouldBlockURL:(NSURL *)url fromMainDocumentURL:(NSURL *)mainUrl;

@end
