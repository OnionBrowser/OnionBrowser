// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "AppDelegate.h"
#import "Bridge.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import <sys/utsname.h>
#import "BridgeViewController.h"

@interface AppDelegate()
- (Boolean)torrcExists;
- (void)afterFirstRun;
@end

@implementation AppDelegate

@synthesize
    sslWhitelistedDomains,
    startUrl,
    appWebView,
    tor = _tor,
    obfsproxy = _obfsproxy,
    window = _window,
    windowOverlay,
    managedObjectContext = __managedObjectContext,
    managedObjectModel = __managedObjectModel,
    persistentStoreCoordinator = __persistentStoreCoordinator,
    doPrepopulateBookmarks,
    usingObfs,
    didLaunchObfsProxy
;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    usingObfs = NO;
    didLaunchObfsProxy = NO;

    // Detect bookmarks file.
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Settings.sqlite"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    doPrepopulateBookmarks = (![fileManager fileExistsAtPath:[storeURL path]]);

    /* Tell iOS to encrypt everything in the app's sandboxed storage. */
    [self updateFileEncryption];
    // Repeat encryption every 15 seconds, to catch new caches, cookies, etc.
    [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(updateFileEncryption) userInfo:nil repeats:YES];
    //[self performSelector:@selector(testEncrypt) withObject:nil afterDelay:8];

    /*********** WebKit options **********/
    // http://objectiveself.com/post/84817251648/uiwebviews-hidden-properties
    // https://git.chromium.org/gitweb/?p=external/WebKit_trimmed.git;a=blob;f=Source/WebKit/mac/WebView/WebPreferences.mm;h=2c25b05ef6a73f478df9b0b7d21563f19aa85de4;hb=9756e26ef45303401c378036dff40c447c2f9401
    // Block JS if we are on "Block All" mode.
    /* TODO: disabled for now, since Content-Security-Policy handles this (and this setting
     * requires app restart to take effect)
    NSInteger blockingSetting = [[settings valueForKey:@"javascript"] integerValue];
    if (blockingSetting == CONTENTPOLICY_STRICT) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitJavaScriptEnabled"];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitJavaScriptEnabledPreferenceKey"];
    } else {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WebKitJavaScriptEnabled"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WebKitJavaScriptEnabledPreferenceKey"];
    }
    */
    // Always disable multimedia (Tor leak)
    // TODO: These don't seem to have any effect on the QuickTime player appearing (and transfering
    //       data outside of Tor). Work-in-progress.
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitAVFoundationEnabledKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitWebAudioEnabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitWebAudioEnabledPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitQTKitEnabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitQTKitEnabledPreferenceKey"];

    // Always disable localstorage & databases
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitDatabasesEnabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitDatabasesEnabledPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitLocalStorageEnabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitLocalStorageEnabledPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setObject:@"/dev/null" forKey:@"WebKitLocalStorageDatabasePath"];
    [[NSUserDefaults standardUserDefaults] setObject:@"/dev/null" forKey:@"WebKitLocalStorageDatabasePathPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setObject:@"/dev/null" forKey:@"WebDatabaseDirectory"];
    [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:@"WebKitStorageBlockingPolicy"];
    [[NSUserDefaults standardUserDefaults] setInteger:2 forKey:@"WebKitStorageBlockingPolicyKey"];

    // Disable disk-based caches.
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitDiskImageCacheEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    /*********** /WebKit options **********/

    // Wipe all cookies & caches from previous invocations of app (in case we didn't wipe
    // cleanly upon exit last time)
    [self wipeAppData];

    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    appWebView = [[WebViewController alloc] init];
    [_window setRootViewController:appWebView];
    [_window makeKeyAndVisible];

    [self startup2];

    return YES;
}

-(void) startup2 {
/*
    UIAlertController *betaAlert = [UIAlertController alertControllerWithTitle:@"Onion Browser Beta"
        message:@"Thank you for being an Onion Browser beta tester.\n\n📝 To report issues "
            "with this version of the app: Open the TestFlight app, select "
            "Onion Browser, and then click \"Send Feedback\".\n\n🔄 To go back to a non-beta version, uninstall the app and re-install it from the App Store."
        preferredStyle:UIAlertControllerStyleAlert];
    [betaAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self real_startup2];
    }]];
    [_window.rootViewController presentViewController:betaAlert animated:YES completion:NULL];
}
-(void) real_startup2 {
*/
    if (![self torrcExists] && ![self isRunningTests]) {
      UIAlertController *alert2 = [UIAlertController alertControllerWithTitle:@"Welcome to Onion Browser" message:@"If you are in a location that blocks connections to Tor, you may configure bridges before trying to connect for the first time." preferredStyle:UIAlertControllerStyleAlert];

      [alert2 addAction:[UIAlertAction actionWithTitle:@"Connect to Tor" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
          [self afterFirstRun];
      }]];
      [alert2 addAction:[UIAlertAction actionWithTitle:@"Configure Bridges" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
          BridgeViewController *bridgesVC = [[BridgeViewController alloc] initWithStyle:UITableViewStyleGrouped];
          UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bridgesVC];
          navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
          [_window.rootViewController presentViewController:navController animated:YES completion:nil];
      }]];
      [_window.rootViewController presentViewController:alert2 animated:YES completion:NULL];
    } else {
      [self afterFirstRun];
    }

    sslWhitelistedDomains = [[NSMutableSet alloc] init];

    NSMutableDictionary *settings = self.getSettings;
    NSInteger cookieSetting = [[settings valueForKey:@"cookies"] integerValue];
    if (cookieSetting == COOKIES_ALLOW_ALL) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    } else if (cookieSetting == COOKIES_BLOCK_THIRDPARTY) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];
    } else if (cookieSetting == COOKIES_BLOCK_ALL) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyNever];
    }

    // Start the spinner for the "connecting..." phase
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

    /*******************/
    // Clear any previous caches/cookies
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
}

-(void) recheckObfsproxy {
    /* Launches obfs4proxy if it hasn't been launched yet
     * but we have some PT bridges that we didn't have before.
     * NOTE that this does not HUP tor. Caller should also perform
     * that action.
     */
    [self updateTorrc];
    if (usingObfs && !didLaunchObfsProxy) {
      #ifdef DEBUG
      NSLog(@"have obfs* or meek_lite or scramblesuit bridges, will launch obfs4proxy");
      #endif
      [_obfsproxy start];
      didLaunchObfsProxy = YES;
      [NSThread sleepForTimeInterval:0.1];
    }
}
-(void) afterFirstRun {
    /* On very first run of app, we check with user if they want bridges
     * (so we don't dangerously launch un-bridged network connections).
     * After they are done configuring bridges, this happens.
     * On successive runs, we simply jump straight to here on app launch.
     */
    _obfsproxy = [[ObfsWrapper alloc] init];
    [self updateTorrc];
    if (usingObfs && !didLaunchObfsProxy) {
      #ifdef DEBUG
      NSLog(@"have obfs* or meek_lite or scramblesuit bridges, will launch obfs4proxy");
      #endif
      [_obfsproxy start];
      didLaunchObfsProxy = YES;
      [NSThread sleepForTimeInterval:0.1];
    }
    _tor = [[TorController alloc] init];
    [_tor startTor];
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil) {
        return __managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        __managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return __managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil) {
        return __managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"Settings" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return __managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator != nil) {
        return __persistentStoreCoordinator;
    }

    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Settings.sqlite"];

    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                             NSFileProtectionComplete, NSFileProtectionKey,
                             [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];

    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }

    return __persistentStoreCoordinator;
}

- (NSURL *)applicationDocumentsDirectory {
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}



#pragma mark -
#pragma mark App lifecycle

- (void)applicationWillResignActive:(UIApplication *)application {
    NSString *imgurl;

    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *device = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];

    // List as of Oct 22 2015
    if ([device isEqualToString:@"iPhone7,2"] || [device isEqualToString:@"iPhone8,1"]) {
        // iPhone 6 (1334x750 3x)
        imgurl = [[NSBundle mainBundle] pathForResource:@"LaunchImage-800-667h@2x.png" ofType:nil];
    } else if ([device isEqualToString:@"iPhone7,1"] || [device isEqualToString:@"iPhone8,2"]) {
        // iPhone 6 Plus (2208x1242 3x)
        if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation])) {
            imgurl = [[NSBundle mainBundle] pathForResource:@"LaunchImage-800-Portrait-736h@3x.png" ofType:nil];
        } else {
            imgurl = [[NSBundle mainBundle] pathForResource:@"LaunchImage-800-Landscape-736h@3x.png" ofType:nil];
        }
    } else if ([device hasPrefix:@"iPhone5"] || [device hasPrefix:@"iPhone6"] || [device hasPrefix:@"iPod5"] || [device hasPrefix:@"iPod7"]) {
        // iPhone 5/5S/5C (1136x640 2x)
        imgurl = [[NSBundle mainBundle] pathForResource:@"LaunchImage-700-568h@2x.png" ofType:nil];
    } else if ([device hasPrefix:@"iPhone3"] || [device hasPrefix:@"iPhone4"] || [device hasPrefix:@"iPod4"]) {
        // iPhone 4/4S (960x640 2x)
        imgurl = [[NSBundle mainBundle] pathForResource:@"LaunchImage@2x.png" ofType:nil];
    } else if ([device hasPrefix:@"iPad1"] || [device hasPrefix:@"iPad2"]) {
        // OLD IPADS: non-retina
        if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation])) {
            imgurl = [[NSBundle mainBundle] pathForResource:@"LaunchImage-700-Portrait~ipad.png" ofType:nil];
        } else {
            imgurl = [[NSBundle mainBundle] pathForResource:@"LaunchImage-700-Landscape~ipad.png" ofType:nil];
        }
    } else if ([device hasPrefix:@"iPad"]) {
        // ALL OTHER (NEWER) IPADS
        // iPad 4thGen, iPad Air 5thGen, iPad Mini 2ndGen (2048x1536 2x)
        if (UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation])) {
            imgurl = [[NSBundle mainBundle] pathForResource:@"LaunchImage-700-Portrait@2x~ipad.png" ofType:nil];
        } else {
            imgurl = [[NSBundle mainBundle] pathForResource:@"LaunchImage-700-Landscape@2x~ipad.png" ofType:nil];
        }
    } else {
        // Fall back to our highest-res, since it's likely this device is new
        imgurl = [[NSBundle mainBundle] pathForResource:@"LaunchImage-800-667h@2x.png" ofType:nil];
    }
    if (windowOverlay == nil) {
        windowOverlay = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imgurl]];
    }
    [_window addSubview:windowOverlay];
    [_window bringSubviewToFront:windowOverlay];

    [_tor disableTorCheckLoop];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    if (!_tor.didFirstConnect) {
        // User is trying to quit app before we have finished initial
        // connection. This is basically an "abort" situation because
        // backgrounding while Tor is attempting to connect will almost
        // definitely result in a hung Tor client. Quit the app entirely,
        // since this is also a good way to allow user to retry initial
        // connection if it fails.
        #ifdef DEBUG
            NSLog(@"Went to BG before initial connection completed: exiting.");
        #endif
        exit(0);
    } else {
        [_tor disableTorCheckLoop];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    _window.hidden = NO;
    appWebView.view.hidden = NO;
    if (windowOverlay != nil) {
        [windowOverlay removeFromSuperview];
    }

    // Don't want to call "activateTorCheckLoop" directly since we
    // want to HUP tor first.
    [_tor appDidBecomeActive];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Wipe all cookies & caches on the way out.
    [self wipeAppData];
    _window.hidden = YES;
    appWebView.view.hidden = YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    NSString *urlStr = [url absoluteString];
    NSURL *newUrl = nil;

    #ifdef DEBUG
        NSLog(@"Received URL: %@", urlStr);
    #endif

    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    BOOL appIsOnionBrowser = [bundleIdentifier isEqualToString:@"com.miketigas.OnionBrowser"];
    BOOL srcIsOnionBrowser = (appIsOnionBrowser && [sourceApplication isEqualToString:bundleIdentifier]);

    if (appIsOnionBrowser && [urlStr hasPrefix:@"onionbrowser:/"]) {
        // HTTP
        urlStr = [urlStr stringByReplacingCharactersInRange:NSMakeRange(0, 14) withString:@"http:/"];
        #ifdef DEBUG
            NSLog(@" -> %@", urlStr);
        #endif
        newUrl = [NSURL URLWithString:urlStr];
    } else if (appIsOnionBrowser && [urlStr hasPrefix:@"onionbrowsers:/"]) {
        // HTTPS
        urlStr = [urlStr stringByReplacingCharactersInRange:NSMakeRange(0, 15) withString:@"https:/"];
        #ifdef DEBUG
            NSLog(@" -> %@", urlStr);
        #endif
        newUrl = [NSURL URLWithString:urlStr];
    } else {
        return YES;
    }
    if (newUrl == nil) {
        return YES;
    }

    if ([_tor didFirstConnect]) {
        if (srcIsOnionBrowser) {
            [appWebView loadURL:newUrl];
        } else {
            [appWebView askToLoadURL:newUrl];
        }
    } else {
        #ifdef DEBUG
            NSLog(@" -> have not yet connected to tor, deferring load");
        #endif
        startUrl = newUrl;
    }
	return YES;
}

#pragma mark -
#pragma mark App helpers

- (NSUInteger) deviceType{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);

    #ifdef DEBUG
    NSLog(@"%@", platform);
    #endif

    if (([platform rangeOfString:@"iPhone"].location != NSNotFound)||([platform rangeOfString:@"iPod"].location != NSNotFound)) {
        return 0;
    } else if ([platform rangeOfString:@"iPad"].location != NSNotFound) {
        return 1;
    } else {
        return 2;
    }
}

-(NSUInteger) numBridgesConfigured {

	NSFetchRequest *request = [[NSFetchRequest alloc] init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:self.managedObjectContext];
	[request setEntity:entity];

	NSError *error = nil;
	NSMutableArray *mutableFetchResults = [[self.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
	if (mutableFetchResults == nil) {
		// Handle the error.
	}
	return [mutableFetchResults count];
}



- (Boolean)torrcExists {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *destTorrc = [[[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"torrc"] relativePath];
    return [fileManager fileExistsAtPath:destTorrc];
}

- (void)updateTorrc {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *destTorrc = [[[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"torrc"] relativePath];
    if ([fileManager fileExistsAtPath:destTorrc]) {
        [fileManager removeItemAtPath:destTorrc error:NULL];
    }
    NSString *sourceTorrc = [[NSBundle mainBundle] pathForResource:@"torrc" ofType:nil];
    NSError *error = nil;
    [fileManager copyItemAtPath:sourceTorrc toPath:destTorrc error:&error];
    if (error != nil) {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        if (![fileManager fileExistsAtPath:sourceTorrc]) {
            NSLog(@"(Source torrc %@ doesnt exist)", sourceTorrc);
        }
    }

	// If the bridge setting is set to one of the "built-in" sets, make sure
	// we use fresh values as provided by the app. This allows us to update the
	// built-in confs.
	NSMutableDictionary *settings = self.getSettings;
	NSInteger bridgeSetting = [[settings valueForKey:@"bridges"] integerValue];
	if (bridgeSetting == TOR_BRIDGES_OBFS4) {
		[Bridge updateBridgeLines:[Bridge defaultObfs4]];
	} else if (bridgeSetting == TOR_BRIDGES_MEEKAMAZON) {
		[Bridge updateBridgeLines:[Bridge defaultMeekAmazon]];
	} else if (bridgeSetting == TOR_BRIDGES_MEEKAZURE) {
		[Bridge updateBridgeLines:[Bridge defaultMeekAzure]];
	}

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:self.managedObjectContext];
    [request setEntity:entity];

    error = nil;
    NSMutableArray *mutableFetchResults = [[self.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
    if (mutableFetchResults == nil) {

    } else if ([mutableFetchResults count] > 0) {
        NSFileHandle *myHandle = [NSFileHandle fileHandleForWritingAtPath:destTorrc];
        [myHandle seekToEndOfFile];

        [myHandle writeData:[@"UseBridges 1\n" dataUsingEncoding:NSUTF8StringEncoding]];
        for (Bridge *bridge in mutableFetchResults) {
          if ([bridge.conf containsString:@"obfs4"] || [bridge.conf containsString:@"meek_lite"]  || [bridge.conf containsString:@"obfs2"]  || [bridge.conf containsString:@"obfs3"]  || [bridge.conf containsString:@"scramblesuit"] ) {
            usingObfs = YES;
          }
          //NSLog(@"%@", [NSString stringWithFormat:@"Bridge %@\n", bridge.conf]);
          [myHandle writeData:[[NSString stringWithFormat:@"Bridge %@\n", bridge.conf] dataUsingEncoding:NSUTF8StringEncoding]];
        }

        if (usingObfs) {
          // TODO iObfs#1 eventually fix this so we use random ports
          //      and communicate that from obfs4proxy to iOS
          [myHandle writeData:[@"ClientTransportPlugin obfs4 socks5 127.0.0.1:47351\n" dataUsingEncoding:NSUTF8StringEncoding]];
          [myHandle writeData:[@"ClientTransportPlugin meek_lite socks5 127.0.0.1:47352\n" dataUsingEncoding:NSUTF8StringEncoding]];
          [myHandle writeData:[@"ClientTransportPlugin obfs2 socks5 127.0.0.1:47353\n" dataUsingEncoding:NSUTF8StringEncoding]];
          [myHandle writeData:[@"ClientTransportPlugin obfs3 socks5 127.0.0.1:47354\n" dataUsingEncoding:NSUTF8StringEncoding]];
          [myHandle writeData:[@"ClientTransportPlugin scramblesuit socks5 127.0.0.1:47355\n" dataUsingEncoding:NSUTF8StringEncoding]];
        }
		[myHandle closeFile];
    }

    // Encrypt the new torrc (since this "running" copy of torrc may now contain bridges)
    NSDictionary *f_options = [NSDictionary dictionaryWithObjectsAndKeys:
                               NSFileProtectionCompleteUnlessOpen, NSFileProtectionKey, nil];
    [fileManager setAttributes:f_options ofItemAtPath:destTorrc error:nil];
}

- (void)wipeAppData {
    [[self appWebView] stopLoading];

    /* This is probably incredibly redundant since we just delete all the files, below */
    NSHTTPCookie *cookie;
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    [[NSURLCache sharedURLCache] removeAllCachedResponses];


    /* Delete all Caches, Cookies, Preferences in app's "Library" data dir. (Connection settings
     * & etc end up in "Documents", not "Library".) */
    NSArray *dataPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    if ((dataPaths != nil) && ([dataPaths count] > 0)) {
        NSString *dataDir = [dataPaths objectAtIndex:0];
        NSFileManager *fm = [NSFileManager defaultManager];

        if ((dataDir != nil) && [fm fileExistsAtPath:dataDir isDirectory:nil]){
            NSString *cookiesDir = [NSString stringWithFormat:@"%@/Cookies", dataDir];
            if ([fm fileExistsAtPath:cookiesDir isDirectory:nil]){
                [fm removeItemAtPath:cookiesDir error:nil];
            }

            NSString *cachesDir = [NSString stringWithFormat:@"%@/Caches", dataDir];
            if ([fm fileExistsAtPath:cachesDir isDirectory:nil]){
                [fm removeItemAtPath:cachesDir error:nil];
            }

            NSString *prefsDir = [NSString stringWithFormat:@"%@/Preferences", dataDir];
            if ([fm fileExistsAtPath:prefsDir isDirectory:nil]){
                [fm removeItemAtPath:prefsDir error:nil];
            }

            NSString *wkDir = [NSString stringWithFormat:@"%@/WebKit", dataDir];
            if ([fm fileExistsAtPath:wkDir isDirectory:nil]){
                [fm removeItemAtPath:wkDir error:nil];
            }
        }
    } // TODO: otherwise, WTF
}

- (Boolean)isRunningTests {
    NSDictionary* environment = [ [ NSProcessInfo processInfo ] environment ];
    NSString* theTestConfigPath = environment[ @"XCTestConfigurationFilePath" ];
    return theTestConfigPath != nil;
}


- (NSString *)settingsFile {
    return [[[self applicationDocumentsDirectory] path] stringByAppendingPathComponent:@"Settings.plist"];
}

- (NSMutableDictionary *)getSettings {
    NSPropertyListFormat format;
    NSMutableDictionary *d;

    NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:self.settingsFile];
    if (plistXML == nil) {
        // We didn't have a settings file, so we'll want to initialize one now.
        d = [NSMutableDictionary dictionary];
    } else {
       d = (NSMutableDictionary *)[NSPropertyListSerialization propertyListWithData:plistXML options:NSPropertyListMutableContainersAndLeaves format:&format error:nil];
    }

    // SETTINGS DEFAULTS
    // we do this here in case the user has an old version of the settings file and we've
    // added new keys to settings. (or if they have no settings file and we're initializing
    // from a blank slate.)
    Boolean update = NO;
    if ([d objectForKey:@"homepage"] == nil) {
        [d setObject:@"onionbrowser:home" forKey:@"homepage"]; // DEFAULT HOMEPAGE
        update = YES;
    }
    if ([d objectForKey:@"cookies"] == nil) {
        [d setObject:[NSNumber numberWithInteger:COOKIES_BLOCK_THIRDPARTY] forKey:@"cookies"];
        update = YES;
    }
    if (([d objectForKey:@"uaspoof"] == nil) || ([[d objectForKey:@"uaspoof"] integerValue] == UA_SPOOF_UNSET)) {
        if (IS_IPAD) {
            [d setObject:[NSNumber numberWithInteger:UA_SPOOF_IPAD] forKey:@"uaspoof"];
        } else {
            [d setObject:[NSNumber numberWithInteger:UA_SPOOF_IPHONE] forKey:@"uaspoof"];
        }
        update = YES;
    }
    if ([d objectForKey:@"dnt"] == nil) {
        [d setObject:[NSNumber numberWithInteger:DNT_HEADER_UNSET] forKey:@"dnt"];
        update = YES;
    }
    if ([d objectForKey:@"tlsver"] == nil) {
        [d setObject:[NSNumber numberWithInteger:X_TLSVER_TLS1] forKey:@"tlsver"];
        update = YES;
    }
    if ([d objectForKey:@"javascript"] == nil) { // for historical reasons, CSP setting is named "javascript"
        [d setObject:[NSNumber numberWithInteger:CONTENTPOLICY_BLOCK_CONNECT] forKey:@"javascript"];
        update = YES;
    }
	if ([d objectForKey:@"bridges"] == nil) {
		// previous versions of onion browser didn't set this option, instead scanning the stored Bridge config.
		NSFetchRequest *request = [[NSFetchRequest alloc] init];
		NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:self.managedObjectContext];
		[request setEntity:entity];

		NSError *error = nil;
		NSMutableArray *mutableFetchResults = [[self.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
		NSUInteger bridgeConf = TOR_BRIDGES_NONE;
		if ((mutableFetchResults != nil) && ([mutableFetchResults count] > 0)) {
			if (([mutableFetchResults count] == 1)) {
				// previous onion browser: it's built-in meek-lite if there's exactly 1 bridge
				// and it contains one of the two known front domains
				Bridge *bridge = (Bridge *)[mutableFetchResults firstObject];
				if ([bridge.conf containsString:@"front=a0.awsstatic.com"]) {
					bridgeConf = TOR_BRIDGES_MEEKAMAZON;
				} else if ([bridge.conf containsString:@"front=ajax.aspnetcdn.com"]) {
					bridgeConf = TOR_BRIDGES_MEEKAZURE;
				} else {
					bridgeConf = TOR_BRIDGES_CUSTOM;
				}
			} else if (([mutableFetchResults count] == 16)) {
				// previous onion browser: it's built-in obfs4 list if there are exactly 16 bridges
				// and they all are obfs4 bridges
				Boolean allObfs4 = YES;
				for (Bridge *bridge in mutableFetchResults) {
					if (![bridge.conf containsString:@"obfs4"]) {
						allObfs4 = NO;
						break;
					}
				}
				if (allObfs4) {
					bridgeConf = TOR_BRIDGES_OBFS4;
				} else {
					bridgeConf = TOR_BRIDGES_CUSTOM;
				}
			} else {
				bridgeConf = TOR_BRIDGES_CUSTOM;
			}
		}

		[d setObject:[NSNumber numberWithInteger:bridgeConf] forKey:@"bridges"];
		update = YES;
	}
    if (update)
        [self saveSettings:d];
    // END SETTINGS DEFAULTS

    return d;
}

- (void)saveSettings:(NSMutableDictionary *)settings {
    NSError *error;
    NSData *data =
    [NSPropertyListSerialization dataWithPropertyList:settings
                                               format:NSPropertyListXMLFormat_v1_0
                                              options:0
                                                error:&error];
    if (data == nil) {
        NSLog (@"error serializing to xml: %@", error);
        return;
    } else {
        NSUInteger fileOption = NSDataWritingAtomic | NSDataWritingFileProtectionComplete;
        [data writeToFile:self.settingsFile options:fileOption error:nil];
    }
}

- (NSString *)homepage {
    NSMutableDictionary *d = self.getSettings;
    return [d objectForKey:@"homepage"];
}



#ifdef DEBUG
- (void)applicationProtectedDataWillBecomeUnavailable:(UIApplication *)application {
    NSLog(@"app data encrypted");
}
- (void)applicationProtectedDataDidBecomeAvailable:(UIApplication *)application {
    NSLog(@"data decrypted, now available");
}
#endif

- (void)updateFileEncryption {
    /* This will traverse the app's sandboxed storage directory and add the NSFileProtectionCompleteUnlessOpen flag
     * to every file encountered.
     *
     * NOTE: the NSFileProtectionKey setting doesn't have any effect on iOS Simulator OR if user does not
     * have a passcode, since the OS-level encryption relies on the iOS physical device as per
     * https://ssl.apple.com/ipad/business/docs/iOS_Security_Feb14.pdf .
     *
     * To test data encryption:
     *   1 compile and run on your own device (with a passcode)
     *   2 open app, allow app to finish loading, configure app, etc.
     *   3 close app, wait a few seconds for it to sleep, force-quit app
     *   4 open XCode organizer (command-shift-2), go to device, go to Applications, select Onion Browser app
     *   5 click "download"
     *   6 open the xcappdata directory you saved, look for Documents/Settings.plist, etc
     *   - THEN: unlock device, open app, and try steps 4-6 again with the app open & device unlocked.
     *   - THEN: comment out "fileManager setAttributes" line below and test steps 1-6 again.
     *
     * In cases where data is encrypted, the "xcappdata" download received will not contain the encrypted data files
     * (though some lock files and sqlite journal files are kept). If data is not encrypted, the download will contain
     * all files pertinent to the app.
     */
    NSFileManager *fileManager = [NSFileManager defaultManager];

    NSArray *dirs = [NSArray arrayWithObjects:
      [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:@".."],
      [[NSBundle mainBundle] bundleURL],
      [self applicationDocumentsDirectory],
      [NSURL URLWithString:NSTemporaryDirectory()],
      nil
    ];

    for (NSURL *bundleURL in dirs) {

      NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:bundleURL
                                            includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey, NSURLIsHiddenKey]
                                                               options:0
                                                          errorHandler:^(NSURL *url, NSError *error) {
                                                            // ignore errors
                                                            return YES;
                                                          }];

      // NOTE: doNotEncryptAttribute is only up in here because for some versions of Onion
      //       Browser we were encrypting even OnionBrowser.app, which possibly caused
      //       the app to become invisible. so we'll manually set anything inside executable
      //       app to be unencrypted (because it will never store user data, it's just
      //       *our* bundle.)
      NSDictionary *fullEncryptAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
                                 NSFileProtectionComplete, NSFileProtectionKey, nil];
      // allow Tor-related files to be read by the app even when in the background. helps
      // let Tor come back from sleep.
      NSDictionary *torEncryptAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
                                 NSFileProtectionCompleteUnlessOpen, NSFileProtectionKey, nil];
      NSDictionary *doNotEncryptAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
                                        NSFileProtectionNone, NSFileProtectionKey, nil];

      NSString *appDir = [[[[NSBundle mainBundle] bundleURL] absoluteString] stringByReplacingOccurrencesOfString:@"/private/var/" withString:@"/var/"];
      NSString *tmpDirStr = [[[NSURL URLWithString:[NSString stringWithFormat:@"file://%@", NSTemporaryDirectory()]] absoluteString] stringByReplacingOccurrencesOfString:@"/private/var/" withString:@"/var/"];
      #ifdef DEBUG
      NSLog(@"%@", appDir);
      #endif

      for (NSURL *fileURL in enumerator) {
          NSNumber *isDirectory;
          NSString *filePath = [[fileURL absoluteString] stringByReplacingOccurrencesOfString:@"/private/var/" withString:@"/var/"];
          [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

          if (![isDirectory boolValue]) {
              // Directories can't be set to "encrypt"
              if ([filePath hasPrefix:appDir]) {
                  // Don't encrypt the OnionBrowser.app directory, because otherwise
                  // the system will sometimes lose visibility of the app. (We're re-setting
                  // the "NSFileProtectionNone" attribute because prev versions of Onion Browser
                  // may have screwed this up.)
                  #ifdef DEBUG
                  NSLog(@"NO: %@", filePath);
                  #endif
                  [fileManager setAttributes:doNotEncryptAttribute ofItemAtPath:[fileURL path] error:nil];
              } else if (
                [filePath containsString:@"torrc"] ||
                [filePath containsString:@"pt_state"] ||
                [filePath hasPrefix:[NSString stringWithFormat:@"%@cached-certs", tmpDirStr]] ||
                [filePath hasPrefix:[NSString stringWithFormat:@"%@cached-microdesc", tmpDirStr]] ||
                [filePath hasPrefix:[NSString stringWithFormat:@"%@control_auth_cookie", tmpDirStr]] ||
                [filePath hasPrefix:[NSString stringWithFormat:@"%@lock", tmpDirStr]] ||
                [filePath hasPrefix:[NSString stringWithFormat:@"%@state", tmpDirStr]] ||
                [filePath hasPrefix:[NSString stringWithFormat:@"%@tor", tmpDirStr]]
              ) {
                  // Tor related files should be encrypted, but allowed to stay open
                  // if app was open & device locks.
                  #ifdef DEBUG
                  NSLog(@"TOR ENCRYPT: %@", filePath);
                  #endif
                  [fileManager setAttributes:torEncryptAttribute ofItemAtPath:[fileURL path] error:nil];
              } else {
                  // Full encrypt. This is a file (not a directory) that was generated on the user's device
                  // (not part of our .app bundle).
                  #ifdef DEBUG
                  NSLog(@"FULL ENCRYPT: %@", filePath);
                  #endif
                  [fileManager setAttributes:fullEncryptAttribute ofItemAtPath:[fileURL path] error:nil];
              }
          }
      }
    }
}
/*
- (void)testEncrypt {

    NSURL *settingsPlist = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Settings.plist"];
    //NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Settings.sqlite"];
    NSLog(@"protected data available: %@",[[UIApplication sharedApplication] isProtectedDataAvailable] ? @"yes" : @"no");

    NSError *error;

    NSString *test = [NSString stringWithContentsOfFile:[settingsPlist path]
                                                  encoding:NSUTF8StringEncoding
                                                     error:NULL];
    NSLog(@"file contents: %@\nerror: %@", test, error);
}
*/


- (NSString *)javascriptInjection {
    NSMutableString *str = [[NSMutableString alloc] init];

    Byte uaspoof = [[self.getSettings valueForKey:@"uaspoof"] integerValue];
    if (uaspoof == UA_SPOOF_SAFARI_MAC) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/601.7.7 (KHTML, like Gecko) Version/9.1.2 Safari/601.7.7';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'MacIntel';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/601.7.7 (KHTML, like Gecko) Version/9.1.2 Safari/601.7.7';});"];
    } else if (uaspoof == UA_SPOOF_WIN7_TORBROWSER) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (Windows)';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'Win32';});"];
        [str appendString:@"navigator.__defineGetter__('language',function(){return 'en-US';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (Windows NT 6.1; rv:45.0) Gecko/20100101 Firefox/45.0';});"];
    } else if (uaspoof == UA_SPOOF_IPHONE) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (iPhone; CPU iPhone OS 9_3 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13E230 Safari/601.1';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'iPhone';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (iPhone; CPU iPhone OS 9_3 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13E230 Safari/601.1';});"];
    } else if (uaspoof == UA_SPOOF_IPAD) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (iPad; CPU OS 9_3 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13E237 Safari/601.1';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'iPad';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (iPad; CPU OS 9_3 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13E237 Safari/601.1';});"];
    }
    Byte activeContent = [[self.getSettings valueForKey:@"javascript"] integerValue];
    if (activeContent != CONTENTPOLICY_PERMISSIVE) {
        [str appendString:@"function Worker(){};"];
        [str appendString:@"function WebSocket(){};"];
    }
    if (activeContent == CONTENTPOLICY_STRICT) {
        [str appendString:@"function sessionStorage(){};"];
        [str appendString:@"function localStorage(){};"];
        [str appendString:@"function globalStorage(){};"];
        [str appendString:@"function openDatabase(){};"];
    }
    return str;
}
- (NSString *)customUserAgent {
    Byte uaspoof = [[self.getSettings valueForKey:@"uaspoof"] integerValue];
    if (uaspoof == UA_SPOOF_SAFARI_MAC) {
        return @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/601.7.7 (KHTML, like Gecko) Version/9.1.2 Safari/601.7.7";
    } else if (uaspoof == UA_SPOOF_WIN7_TORBROWSER) {
        return @"Mozilla/5.0 (Windows NT 6.1; rv:45.0) Gecko/20100101 Firefox/45.0";
    } else if (uaspoof == UA_SPOOF_IPHONE) {
        return @"Mozilla/5.0 (iPhone; CPU iPhone OS 9_3 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13E230 Safari/601.1";
    } else if (uaspoof == UA_SPOOF_IPAD) {
        return @"Mozilla/5.0 (iPad; CPU OS 9_3 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13E237 Safari/601.1";
    }
    return nil;
}

@end
