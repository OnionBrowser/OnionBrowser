/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "Bookmark.h"
#import "HTTPSEverywhere.h"
#import "URLInterceptor.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	@try {
		NSURL *resourceURL = [[NSBundle mainBundle] URLForResource:@"fabric.apikey" withExtension:nil];
		if (resourceURL) {
			NSString *fabricAPIKey = [[NSString stringWithContentsOfURL:resourceURL usedEncoding:nil error:nil] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			CrashlyticsKit.delegate = self;
			[Crashlytics startWithAPIKey:fabricAPIKey];
		} else {
			NSLog(@"no fabric.apikey found, not enabling fabric");
		}
	}
	@catch (NSException *e) {
		NSLog(@"[AppDelegate] failed setting up fabric: %@", e);
	}

#ifdef USE_DUMMY_URLINTERCEPTOR
	[NSURLProtocol registerClass:[DummyURLInterceptor class]];
#else
	[NSURLProtocol registerClass:[URLInterceptor class]];
#endif
	
	self.hstsCache = [HSTSCache retrieve];
	self.cookieJar = [[CookieJar alloc] init];
	[Bookmark retrieveList];
	
	[self initializeDefaults];
	
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.backgroundColor = [UIColor groupTableViewBackgroundColor];
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
	[application ignoreSnapshotOnNextApplicationLaunch];
	[[self webViewController] viewIsNoLongerVisible];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	if (![self areTesting]) {
		[HostSettings persist];
		[[self hstsCache] persist];
	}
	
	if ([userDefaults boolForKey:@"clear_on_background"]) {
		[[self webViewController] removeAllTabs];
		[[self cookieJar] clearAllNonWhitelistedData];
	}
	else
		[[self cookieJar] clearAllOldNonWhitelistedData];
	
	[application ignoreSnapshotOnNextApplicationLaunch];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	[[self webViewController] viewIsVisible];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	/* this definitely ends our sessions */
	[[self cookieJar] clearAllNonWhitelistedData];
	
	[application ignoreSnapshotOnNextApplicationLaunch];
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
#ifdef DEBUG
	NSLog(@"[AppDelegate] request to open url \"%@\"", url);
#endif
	if ([[[url scheme] lowercaseString] isEqualToString:@"endlesshttp"])
		url = [NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"endlesshttp" length]) withString:@"http"]];
	else if ([[[url scheme] lowercaseString] isEqualToString:@"endlesshttps"])
		url = [NSURL URLWithString:[[url absoluteString] stringByReplacingCharactersInRange:NSMakeRange(0, [@"endlesshttps" length]) withString:@"https"]];

	[[self webViewController] dismissViewControllerAnimated:YES completion:nil];
	[[self webViewController] addNewTabForURL:url];
	
	return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
	if ([self areTesting])
		return NO;
	
	/* if we tried last time and failed, the state might be corrupt */
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if ([userDefaults objectForKey:STATE_RESTORE_TRY_KEY] != nil) {
		NSLog(@"[AppDelegate] previous startup failed, not restoring application state");
		[userDefaults removeObjectForKey:STATE_RESTORE_TRY_KEY];
		return NO;
	}
	else
		[userDefaults setBool:YES forKey:STATE_RESTORE_TRY_KEY];
	
	[userDefaults synchronize];

	return YES;
}

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
	if ([self areTesting])
		return NO;
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	if ([userDefaults boolForKey:@"clear_on_background"])
		return NO;

	return YES;
}

- (void)crashlyticsDidDetectReportForLastExecution:(CLSReport *)report completionHandler:(void (^)(BOOL))completionHandler
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
#ifdef TRACE
	NSLog(@"crashlytics report found, %@sending to crashlytics: %@", ([userDefaults boolForKey:@"crash_reporting"] ? @"" : @"NOT "), report);
#endif

	completionHandler([userDefaults boolForKey:@"crash_reporting"]);
}

- (void)initializeDefaults
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	NSString *plistPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"InAppSettings.bundle"] stringByAppendingPathComponent:@"Root.inApp.plist"];
	NSDictionary *settingsDictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];

	for (NSDictionary *pref in [settingsDictionary objectForKey:@"PreferenceSpecifiers"]) {
		NSString *key = [pref objectForKey:@"Key"];
		if (key == nil)
			continue;

		if ([userDefaults objectForKey:key] == NULL) {
			NSObject *val = [pref objectForKey:@"DefaultValue"];
			if (val == nil)
				continue;
			
			[userDefaults setObject:val forKey:key];
#ifdef TRACE
			NSLog(@"[AppDelegate] initialized default preference for %@ to %@", key, val);
#endif
		}
	}
	
	if (![userDefaults synchronize]) {
		NSLog(@"[AppDelegate] failed saving preferences");
		abort();
	}
	
	_searchEngines = [NSMutableDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"SearchEngines.plist"]];
}

- (BOOL)areTesting
{
	if (NSClassFromString(@"XCTestProbe") != nil) {
		NSLog(@"we are testing");
		return YES;
	}
	else {
		NSDictionary *environment = [[NSProcessInfo processInfo] environment];
		if (environment[@"ARE_UI_TESTING"]) {
			NSLog(@"we are UI testing");
			return YES;
		}
	}
	
	return NO;
}

@end
