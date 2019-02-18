/*
 * Endless
 * Copyright (c) 2014-2017 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

#import "CookieJar.h"
#import "HSTSCache.h"
#import "WebViewController.h"

#define STATE_RESTORE_TRY_KEY @"state_restore_lock"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (strong, atomic) WebViewController *webViewController;
@property (strong, atomic) CookieJar *cookieJar;
@property (strong, atomic) HSTSCache *hstsCache;

@property (readonly, strong, nonatomic) NSMutableDictionary *searchEngines;

@property (strong, atomic) NSString *defaultUserAgent;
@property (strong, atomic) NSURL *urlToOpenAtLaunch;

@property (atomic) NSUInteger torState;

- (BOOL)areTesting;

@end

