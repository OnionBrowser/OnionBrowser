#import <Foundation/Foundation.h>
#import "HTTPSEverywhereRule.h"

@interface HTTPSEverywhere : NSObject

+ (NSDictionary *)rules;
+ (NSDictionary *)targets;
+ (NSMutableDictionary *)disabledRules;
+ (void)saveDisabledRules;

+ (HTTPSEverywhereRule *)cachedRuleForName:(NSString *)name;
+ (NSArray *)potentiallyApplicableRulesForHost:(NSString *)host;
+ (NSURL *)rewrittenURI:(NSURL *)URL withRules:(NSArray *)rules;
+ (BOOL)needsSecureCookieFromHost:(NSString *)fromHost forHost:(NSString *)forHost cookieName:(NSString *)cookie;
+ (void)noteInsecureRedirectionForURL:(NSURL *)URL;

@end
