#import <Foundation/Foundation.h>
#import "HTTPSEverywhereRule.h"

@interface HTTPSEverywhere : NSObject

+ (NSDictionary *)rules;
+ (NSDictionary *)targets;

+ (HTTPSEverywhereRule *)cachedRuleForName:(NSString *)name;
+ (NSArray *)potentiallyApplicableRulesFor:(NSString *)host;
+ (NSURL *)rewrittenURI:(NSURL *)URL;

@end
