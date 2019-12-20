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

#import "JAHPAuthenticatingHTTPProtocol.h"
#import "CertificateAuthentication.h"

@class BrowsingViewController;

#define STATE_RESTORE_TRY_KEY @"state_restore_lock"

@interface AppDelegate : UIResponder <UIApplicationDelegate, JAHPAuthenticatingHTTPProtocolDelegate>

@property (strong, nonatomic, nonnull) UIWindow *window;

@property (strong, nonatomic, nullable) BrowsingViewController *browsingUi;
@property (strong, readonly, nonnull) CookieJar *cookieJar;
@property (strong, readonly, nonnull) HSTSCache *hstsCache;

@property (strong, readonly, nullable) NSString *defaultUserAgent;
@property (strong, nonatomic, nullable) NSURL *urlToOpenAtLaunch;

@property NSInteger socksProxyPort;
@property NSInteger httpProxyPort;
@property (strong, readonly, nonnull) NSCache *sslCertCache;
@property (strong, readonly, nonnull) CertificateAuthentication *certificateAuthentication;

+ (AppDelegate *_Nonnull)sharedAppDelegate;

- (BOOL)areTesting;
- (void)adjustMuteSwitchBehavior;

@end

