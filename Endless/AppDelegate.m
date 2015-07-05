#import "AppDelegate.h"
#import "HTTPSEverywhere.h"
#import "URLInterceptor.h"

@implementation AppDelegate

NSString *const STATE_RESTORE_TRY_KEY = @"state_restore_lock";

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[NSURLProtocol registerClass:[URLInterceptor class]];
	
	_hstsCache = [HSTSCache retrieve];
	_cookieJar = [[CookieJar alloc] init];
	
	[self initializeDefaults];
	
	self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
	self.window.rootViewController = [[WebViewController alloc] init];
	self.window.rootViewController.restorationIdentifier = @"WebViewController";
	
	return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[self.window makeKeyAndVisible];

	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	[[self cookieJar] persist];
	[[self hstsCache] persist];
	
	if ([userDefaults boolForKey:@"clear_on_background"]) {
		[[self webViewController] removeAllTabs];
		[[self cookieJar] clearAllNonWhitelistedData];
	}
	else
		[[self cookieJar] clearAllOldNonWhitelistedData];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
	[[self webViewController] viewIsVisible];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	/* this definitely ends our sessions */
	[[self cookieJar] clearAllNonWhitelistedData];
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
	/* if we tried last time and failed, the state might be corrupt */
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if ([userDefaults objectForKey:STATE_RESTORE_TRY_KEY] != nil) {
		NSLog(@"previous startup failed, not restoring application state");
		[userDefaults removeObjectForKey:STATE_RESTORE_TRY_KEY];
		return NO;
	}
	else
		[userDefaults setBool:@YES forKey:STATE_RESTORE_TRY_KEY];
	
	[userDefaults synchronize];

	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString *)kCFBundleVersionKey];
	NSString *storedVersion = [coder decodeObjectForKey:UIApplicationStateRestorationBundleVersionKey];
	if (![version isEqualToString:storedVersion]) {
#ifdef TRACE
		NSLog(@"not restoring application state, old version %@ != %@", storedVersion, version);
#endif
		return NO;
	}
	
	return YES;
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if ([userDefaults boolForKey:@"clear_on_background"])
		return NO;

	return YES;
}

- (void)initializeDefaults
{
	/* TODO: read defaults from the plist */
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	NSString *plistPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"InAppSettings.bundle"] stringByAppendingPathComponent:@"Root.inApp.plist"];
	NSDictionary *settingsDictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];

	for (NSDictionary *pref in [settingsDictionary objectForKey:@"PreferenceSpecifiers"]) {
		NSString *key = [pref objectForKey:@"Key"];
		if (key == nil)
			continue;

		if ([userDefaults objectForKey:key] == NULL) {
			NSObject *val = [pref objectForKey:@"DefaultValue"];
			[userDefaults setObject:val forKey:key];
#ifdef TRACE
			NSLog(@"initialized default preference for %@ to %@", key, val);
#endif
		}
	}
	
	[userDefaults synchronize];
	
	_searchEngines = [NSMutableDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"SearchEngines.plist"]];
}

@end
