// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <UIKit/UIKit.h>
#import "WebViewController.h"
#import "TorController.h"
#import "ObfsWrapper.h"

#define COOKIES_ALLOW_ALL 0
#define COOKIES_BLOCK_THIRDPARTY 1
#define COOKIES_BLOCK_ALL 2

// Sets "Content-Security-Policy" headers. See ProxyURLController.m
#define CONTENTPOLICY_STRICT 0 // Blocks nearly every CSP type
#define CONTENTPOLICY_BLOCK_CONNECT 1 // Blocks `connect-src` (XHR, CORS, WebSocket)
#define CONTENTPOLICY_PERMISSIVE 2 // Allows all content (DANGEROUS: websockets leak outside tor)

#define UA_SPOOF_UNSET 0
#define UA_SPOOF_WIN7_TORBROWSER 1
#define UA_SPOOF_SAFARI_MAC 2
#define UA_SPOOF_IPHONE 3
#define UA_SPOOF_IPAD 4
#define UA_SPOOF_NO 5

#define DNT_HEADER_UNSET 0
#define DNT_HEADER_CANTRACK 1
#define DNT_HEADER_NOTRACK 2

#define X_DEVICE_IS_IPHONE 0
#define X_DEVICE_IS_IPAD 1
#define X_DEVICE_IS_SIM 2

#define X_TLSVER_ANY 0
#define X_TLSVER_TLS1 1
#define X_TLSVER_TLS1_2_ONLY 2

#define TOR_BRIDGES_NONE 0
#define TOR_BRIDGES_OBFS4 1
#define TOR_BRIDGES_MEEKAMAZON 2
#define TOR_BRIDGES_MEEKAZURE 3
#define TOR_BRIDGES_CUSTOM 99

#define OB_IPV4V6_AUTO 0
#define OB_IPV4V6_V4ONLY 1
#define OB_IPV4V6_V6ONLY 2
#define OB_IPV4V6_FORCEDUAL 3


@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) TorController *tor;
@property (strong, nonatomic) ObfsWrapper *obfsproxy;


@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UIImageView *windowOverlay;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic) WebViewController *appWebView;

// either nil (to load regular homepage) or url given by a "onionbrowser://" (HTTP)
// or "onionbrowsers://" (HTTPS) callback url -- when this app is started from another app
@property (nonatomic) NSURL *startUrl;

// list for known domains w/self-signed certs
@property (nonatomic) NSMutableSet *sslWhitelistedDomains;

@property (nonatomic) Boolean doPrepopulateBookmarks;

@property (nonatomic) Boolean usingObfs;
@property (nonatomic) Boolean didLaunchObfsProxy;

- (void)recheckObfsproxy;
- (NSUInteger) numBridgesConfigured;
- (void)updateTorrc;
- (NSURL *)applicationLibraryDirectory;
- (NSURL *)applicationDocumentsDirectory;
- (void)wipeAppData;
- (NSUInteger) deviceType;
- (Boolean) isRunningTests;

- (NSString *)settingsFile;
- (NSMutableDictionary *)getSettings;
- (void)saveSettings:(NSMutableDictionary *)settings;
- (NSString *)homepage;

- (void)updateFileEncryption;

- (NSString *)javascriptInjection;
- (NSString *)customUserAgent;

//- (void) testEncrypt;

@end
