//
//  AppDelegate.m
//  OnionBrowser
//
//  Copyright (c) 2012 Mike Tigas. All rights reserved.
//

#import "AppDelegate.h"
#include <Openssl/sha.h>
#import "Bridge.h"
#include <sys/types.h>
#include <sys/sysctl.h>

@implementation AppDelegate

@synthesize
    sslWhitelistedDomains,
    startUrl,
    appWebView,
    tor = _tor,
    window = _window,
    windowOverlay,
    managedObjectContext = __managedObjectContext,
    managedObjectModel = __managedObjectModel,
    persistentStoreCoordinator = __persistentStoreCoordinator,
    doPrepopulateBookmarks
;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Detect bookmarks file.
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"Settings.sqlite"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    doPrepopulateBookmarks = (![fileManager fileExistsAtPath:[storeURL path]]);
    
    /* Tell iOS to encrypt everything in the app's sandboxed storage. */
    [self updateFileEncryption];
    // Repeat encryption every 15 seconds, to catch new caches, cookies, etc.
    [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(updateFileEncryption) userInfo:nil repeats:YES];
    //[self performSelector:@selector(testEncrypt) withObject:nil afterDelay:8];

    NSMutableDictionary *settings = self.getSettings;

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

    // Always disable caches
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitUsesPageCache"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitUsesPageCachePreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitPageCacheSupportsPlugins"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitPageCacheSupportsPluginsPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitOfflineWebApplicationCacheEnabled"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitOfflineWebApplicationCacheEnabledPreferenceKey"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"WebKitDiskImageCacheEnabled"];
    [[NSUserDefaults standardUserDefaults] setObject:@"/dev/null" forKey:@"WebKitLocalCache"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    /*********** /WebKit options **********/

    // Wipe all cookies & caches from previous invocations of app (in case we didn't wipe
    // cleanly upon exit last time)
    [self wipeAppData];

    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    appWebView = [[WebViewController alloc] init];
    [_window setRootViewController:appWebView];
    [_window makeKeyAndVisible];
    
    [self updateTorrc];
    _tor = [[TorController alloc] init];
    [_tor startTor];

    sslWhitelistedDomains = [[NSMutableArray alloc] init];
    
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
    
    return YES;
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
        __managedObjectContext = [[NSManagedObjectContext alloc] init];
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
    appWebView.view.hidden = YES;
    NSURL *imgurl = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"../OnionBrowser.app/Default-7-Portrait@2x.png"];
    if (windowOverlay == nil) {
        windowOverlay = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:[imgurl path]]];
    }
    [_window addSubview:windowOverlay];

    [_tor disableTorCheckLoop];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    _window.hidden = YES;
    appWebView.view.hidden = YES;

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
            if ([bridge.conf isEqualToString:@"Tap Here To Edit"]||[bridge.conf isEqualToString:@""]) {
                // skip
            } else {
                [myHandle writeData:[[NSString stringWithFormat:@"bridge %@\n", bridge.conf]
                                     dataUsingEncoding:NSUTF8StringEncoding]];
            }
        }
    }

    // Encrypt the new torrc (since this "running" copy of torrc may now contain bridges)
    NSDictionary *f_options = [NSDictionary dictionaryWithObjectsAndKeys:
                               NSFileProtectionComplete, NSFileProtectionKey, nil];
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
    NSDictionary* environment = [[NSProcessInfo processInfo] environment];
    NSString* injectBundle = environment[@"XCInjectBundle"];
    return [[injectBundle pathExtension] isEqualToString:@"xctest"];
}


- (NSString *)settingsFile {
    return [[[self applicationDocumentsDirectory] path] stringByAppendingPathComponent:@"Settings.plist"];
}

- (NSMutableDictionary *)getSettings {
    NSString *errorDesc = nil;
    NSPropertyListFormat format;
    NSMutableDictionary *d;

    NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:self.settingsFile];
    if (plistXML == nil) {
        // We didn't have a settings file, so we'll want to initialize one now.
        d = [NSMutableDictionary dictionary];
    } else {
        d = (NSMutableDictionary *)[NSPropertyListSerialization
                                              propertyListFromData:plistXML
                                              mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                              format:&format errorDescription:&errorDesc];
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
    if ([d objectForKey:@"javascript"] == nil) { // for historical reasons, CSP setting is named "javascript"
        [d setObject:[NSNumber numberWithInteger:CONTENTPOLICY_BLOCK_CONNECT] forKey:@"javascript"];
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
    /* This will traverse the app's sandboxed storage directory and add the NSFileProtectionComplete flag
     * to every file encountered.
     *
     * NOTE: the NSFileProtectionKey setting doesn't have any effect on iOS Simulator OR if user does not
     * have a passcode, since the OS-level encryption relies on the iOS physical device as per
     * https://ssl.apple.com/ipad/business/docs/iOS_Security_Feb14.pdf .
     *
     * To test data encryption:
     *   1 compile and run on your own device (with a passcode)
     *   2 open app, allow app to finish loading
     *   3 lock device (top button) without exiting app first
     *   4 plug device in and turn screen on, but leave it at lock screen
     *   5 open XCode organizer (command-shift-2), go to device, go to Applications, select Onion Browser app
     *   6 click "download"
     *   7 open the xcappdata directory you saved, look for Documents/Settings.plist, etc
     *   - THEN: unlock device (go to regular home screen) and try steps 4-7 again with the device unlocked.
     *   - THEN: comment out "fileManager setAttributes" line below and test steps 1-7 again.
     *
     * In cases where data is encrypted, the "xcappdata" download received will not contain the encrypted data files
     * (though some lock files and sqlite journal files are kept). If data is not encrypted, the download will contain
     * all files pertinent to the app.
     */
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *bundleURL = [[[NSBundle mainBundle] bundleURL] URLByAppendingPathComponent:@".."];
    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:bundleURL
                                          includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
                                                             options:0
                                                        errorHandler:nil];

    // NOTE: doNotEncryptAttribute is only up in here because for some versions of Onion
    //       Browser we were encrypting even OnionBrowser.app, which possibly caused
    //       the app to become invisible. so we'll manually set anything inside executable
    //       app to be unencrypted (because it will never store user data, it's just
    //       *our* bundle.)
    NSDictionary *encryptAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
                               NSFileProtectionComplete, NSFileProtectionKey, nil];
    NSDictionary *doNotEncryptAttribute = [NSDictionary dictionaryWithObjectsAndKeys:
                                      NSFileProtectionNone, NSFileProtectionKey, nil];

    for (NSURL *fileURL in enumerator) {
        NSNumber *isDirectory;
        [fileURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];

        if (![isDirectory boolValue]) {
            // Directories can't be set to "encrypt"
            if ([[fileURL path] hasPrefix:[[[NSBundle mainBundle] bundleURL] path]]) {
                // Don't encrypt the OnionBrowser.app directory, because otherwise
                // the system will sometimes lose visibility of the app. (We're re-setting
                // the "NSFileProtectionNone" attribute because prev versions of Onion Browser
                // may have screwed this up.)
                [fileManager setAttributes:doNotEncryptAttribute ofItemAtPath:[fileURL path] error:nil];
            } else {
                // Encrypt. This is a file (not a directory) that was generated on the user's device
                // (not part of our .app bundle).
                [fileManager setAttributes:encryptAttribute ofItemAtPath:[fileURL path] error:nil];
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
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.75.14 (KHTML, like Gecko) Version/7.0.3 Safari/537.75.14';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'MacIntel';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.75.14 (KHTML, like Gecko) Version/7.0.3 Safari/537.75.14';});"];
    } else if (uaspoof == UA_SPOOF_WIN7_TORBROWSER) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (Windows)';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'Win32';});"];
        [str appendString:@"navigator.__defineGetter__('language',function(){return 'en-US';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (Windows NT 6.1; rv:24.0) Gecko/20100101 Firefox/24.0';});"];
    } else if (uaspoof == UA_SPOOF_IPHONE) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (iPhone; CPU iPhone OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'iPhone';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (iPhone; CPU iPhone OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53';});"];
    } else if (uaspoof == UA_SPOOF_IPAD) {
        [str appendString:@"var __originalNavigator = navigator;"];
        [str appendString:@"navigator = new Object();"];
        [str appendString:@"navigator.__proto__ = __originalNavigator;"];
        [str appendString:@"navigator.__defineGetter__('appCodeName',function(){return 'Mozilla';});"];
        [str appendString:@"navigator.__defineGetter__('appName',function(){return 'Netscape';});"];
        [str appendString:@"navigator.__defineGetter__('appVersion',function(){return '5.0 (iPad; CPU OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53';});"];
        [str appendString:@"navigator.__defineGetter__('platform',function(){return 'iPad';});"];
        [str appendString:@"navigator.__defineGetter__('userAgent',function(){return 'Mozilla/5.0 (iPad; CPU OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53';});"];
    }

    Byte activeContent = [[self.getSettings valueForKey:@"javascript"] integerValue];
    if (activeContent != CONTENTPOLICY_PERMISSIVE) {
        [str appendString:@"function WebSocket(){};"];
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
        return @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_2) AppleWebKit/537.75.14 (KHTML, like Gecko) Version/7.0.3 Safari/537.75.14";
    } else if (uaspoof == UA_SPOOF_WIN7_TORBROWSER) {
        return @"Mozilla/5.0 (Windows NT 6.1; rv:24.0) Gecko/20100101 Firefox/24.0";
    } else if (uaspoof == UA_SPOOF_IPHONE) {
        return @"Mozilla/5.0 (iPhone; CPU iPhone OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53";
    } else if (uaspoof == UA_SPOOF_IPAD) {
        return @"Mozilla/5.0 (iPad; CPU OS 7_1_1 like Mac OS X) AppleWebKit/537.51.2 (KHTML, like Gecko) Version/7.0 Mobile/11D201 Safari/9537.53";
    }
    return nil;
}

@end