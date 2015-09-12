/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

@interface URLBlocker : NSObject

+ (NSDictionary *)targets;

+ (BOOL)shouldBlockURL:(NSURL *)url;
+ (BOOL)shouldBlockURL:(NSURL *)url fromMainDocumentURL:(NSURL *)mainUrl;

@end
