/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

@interface LocalNetworkChecker : NSObject

+ (void)clearCache;
+ (BOOL)isHostOnLocalNet:(NSString *)host;

@end
