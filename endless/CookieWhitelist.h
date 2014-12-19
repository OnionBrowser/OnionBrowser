#import <Foundation/Foundation.h>

/* subclassing NSMutableDictionary is not easy, so we have to use composition */

@interface CookieWhitelist : NSObject
{
	NSMutableDictionary *dict;
}

@property NSMutableDictionary *dict;

+ (CookieWhitelist *)retrieve;
- (void)persist;
- (void)updateHostsWithArray:(NSArray *)hosts;
- (BOOL)isHostWhitelisted:(NSString *)host;

/* NSMutableDictionary composition pass-throughs */
- (id)objectForKey:(id)aKey;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
- (void)setValue:(id)value forKey:(NSString *)key;
- (void)removeObjectForKey:(id)aKey;
- (NSArray *)allKeys;

@end
