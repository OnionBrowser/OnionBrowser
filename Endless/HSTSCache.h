/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

#define HSTS_HEADER @"Strict-Transport-Security"
#define HSTS_KEY_EXPIRATION @"expiration"
#define HSTS_KEY_ALLOW_SUBDOMAINS @"allowSubdomains"
#define HSTS_KEY_PRELOADED @"preloaded"

/* subclassing NSMutableDictionary is not easy, so we have to use composition */

@interface HSTSCache : NSObject
{
	NSMutableDictionary *_dict;
}

@property NSMutableDictionary *dict;

+ (HSTSCache *)retrieve;

- (void)persist;
- (NSURL *)rewrittenURI:(NSURL *)URL;
- (void)parseHSTSHeader:(NSString *)header forHost:(NSString *)host;

/* NSMutableDictionary composition pass-throughs */
- (id)objectForKey:(id)aKey;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
- (void)setValue:(id)value forKey:(NSString *)key;
- (void)removeObjectForKey:(id)aKey;
- (NSArray *)allKeys;

@end
