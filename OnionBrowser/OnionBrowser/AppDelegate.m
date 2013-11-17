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
    spoofUserAgent,
    dntHeader,
    usePipelining,
    sslWhitelistedDomains,
    appWebView,
    tor = _tor,
    window = _window,
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
    
    spoofUserAgent = UA_SPOOF_NO;
    dntHeader = DNT_HEADER_UNSET;
    usePipelining = YES;
    
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
}

- (void)wipeAppData {
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
                //NSLog(@"COOKIES DIR");
                [fm removeItemAtPath:cookiesDir error:nil];
            }
            NSString *cachesDir = [NSString stringWithFormat:@"%@/Caches", dataDir];
            if ([fm fileExistsAtPath:cachesDir isDirectory:nil]){
                //NSLog(@"CACHES DIR");
                [fm removeItemAtPath:cachesDir error:nil];
            }
            NSString *prefsDir = [NSString stringWithFormat:@"%@/Preferences", dataDir];
            if ([fm fileExistsAtPath:prefsDir isDirectory:nil]){
                //NSLog(@"PREFS DIR");
                [fm removeItemAtPath:prefsDir error:nil];
            }
        }
    } // TODO: otherwise, WTF
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
    // Don't want to call "activateTorCheckLoop" directly since we
    // want to HUP tor first.
    [_tor appDidBecomeActive];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Wipe all cookies & caches on the way out.
    [self wipeAppData];
}

- (NSUInteger) deviceType{
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithUTF8String:machine];
    free(machine);

    //NSLog(@"%@", platform);

    if (([platform rangeOfString:@"iPhone"].location != NSNotFound)||([platform rangeOfString:@"iPod"].location != NSNotFound)) {
        return 0;
    } else if ([platform rangeOfString:@"iPad"].location != NSNotFound) {
        return 1;
    } else {
        return 2;
    }
}


@end
