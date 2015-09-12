/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

@interface HTTPSEverywhereRule : NSObject

@property NSString *name;
@property NSArray *exclusions;
@property NSDictionary *rules;
@property NSDictionary *secureCookies;
@property NSString *platform;
@property BOOL on_by_default;
@property NSString *notes;
/* not loaded here since HTTPSEverywhere class has a big list of them */
@property NSArray *targets;

- (id)initWithDictionary:(NSDictionary *)dict;
- (NSURL *)apply:(NSURL *)url;

@end
