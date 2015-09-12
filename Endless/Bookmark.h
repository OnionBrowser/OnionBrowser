/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

@interface Bookmark : NSObject

@property (strong) NSString *name;
@property (strong) NSURL *url;

- (NSString *)urlString;
- (void)setUrlString:(NSString *)urls;

+ (void)retrieveList;
+ (void)persistList;
+ (NSMutableArray *)list;
+ (void)addBookmarkForURLString:(NSString *)urls withName:(NSString *)name;
+ (BOOL)isURLBookmarked:(NSURL *)url;
+ (UIAlertController *)addBookmarkDialogWithOkCallback:(void (^)(void))callback;

@end
