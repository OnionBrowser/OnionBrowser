//
//  AppDelegate.h
//  OnionBrowser
//
//  Copyright (c) 2012 Mike Tigas. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WebViewController.h"
#import "TorController.h"

#define COOKIES_ALLOW_ALL 0
#define COOKIES_BLOCK_THIRDPARTY 1
#define COOKIES_BLOCK_ALL 2

#define JAVASCRIPT_DISABLED 0
#define JAVASCRIPT_ENABLED 1

#define UA_SPOOF_NO 0
#define UA_SPOOF_WIN7_TORBROWSER 1
#define UA_SPOOF_SAFARI_MAC 2

#define PIPELINING_OFF 0
#define PIPELINING_ON 1

#define DNT_HEADER_UNSET 0
#define DNT_HEADER_CANTRACK 1
#define DNT_HEADER_NOTRACK 2

#define X_DEVICE_IS_IPHONE 0
#define X_DEVICE_IS_IPAD 1
#define X_DEVICE_IS_SIM 2

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) TorController *tor;

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (nonatomic) WebViewController *appWebView;

// either nil (to load regular homepage) or url given by a "onionbrowser://" (HTTP)
// or "onionbrowsers://" (HTTPS) callback url -- when this app is started from another app
@property (nonatomic) NSURL *startUrl;

// list for known domains w/self-signed certs
@property (nonatomic) NSMutableArray *sslWhitelistedDomains;

@property (nonatomic) Boolean doPrepopulateBookmarks;

- (void)updateTorrc;
- (NSURL *)applicationDocumentsDirectory;
- (void)wipeAppData;
- (NSUInteger) deviceType;
- (Boolean) isRunningTests;

- (NSString *)settingsFile;
- (NSMutableDictionary *)getSettings;
- (void)saveSettings:(NSMutableDictionary *)settings;
- (NSString *)homepage;

@end
