/*
 * Endless
 * Copyright (c) 2014-2017 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

@interface URLBlocker : NSObject

+ (NSDictionary *)targets;
+ (NSMutableDictionary *)disabledTargets;
+ (void)saveDisabledTargets;

+ (BOOL)shouldBlockURL:(NSURL *)url;
+ (NSString *)blockingTargetForURL:(NSURL *)url fromMainDocumentURL:(NSURL *)mainUrl;
+ (void)enableTargetByHost:(NSString *)target;
+ (void)disableTargetByHost:(NSString *)target withReason:(NSString *)reason;

@end
