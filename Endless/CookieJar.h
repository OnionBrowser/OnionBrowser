#import <Foundation/Foundation.h>

@interface CookieJar : NSObject

@property (strong, atomic) NSHTTPCookieStorage *cookieStorage;
@property NSMutableDictionary *whitelist;
@property NSMutableDictionary *localStorage;

- (void)persist;
- (NSArray *)whitelistedHosts;
- (NSArray *)sortedHostCounts;
- (BOOL)isHostWhitelisted:(NSString *)host;
- (void)clearTransientData;
- (void)clearTransientDataForHost:(NSString *)host;
- (void)updateWhitelistedHostsWithArray:(NSArray *)hosts;

- (NSArray *)cookiesForURL:(NSURL *)url;
- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)URL mainDocumentURL:(NSURL *)mainDocumentURL;

@end
