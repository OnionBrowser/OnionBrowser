#import "AppDelegate.h"
#import "URLInterceptor.h"

@interface AppDelegate ()
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Override point for customization after application launch.
	[NSURLProtocol registerClass:[URLInterceptor class]];
	
	_cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	[_cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];

	self.evHosts = [[NSMutableDictionary alloc] initWithCapacity:5];
	
	[self initializeDefaults];

	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	// Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
	// Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	// Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
	// If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
	// Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	// Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	// Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
	// Saves changes in the application's managed object context before the application terminates.
	[self saveContext];
}

- (void)dumpCookies
{
	NSLog(@"cookie dump:");
	for (NSHTTPCookie *cookie in [[self cookieStorage] cookies]) {
		NSLog(@"  %@: \"%@\"=\"%@\"", cookie.domain, cookie.name, cookie.value);
	}
}

- (void)initializeDefaults
{
	/* TODO: read defaults from the plist */
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	NSString *plistPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"InAppSettings.bundle"] stringByAppendingPathComponent:@"Root.plist"];
	NSDictionary *settingsDictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];
	
	for (NSDictionary *pref in [settingsDictionary objectForKey:@"PreferenceSpecifiers"]) {
		NSString *key = [pref objectForKey:@"Key"];
		if ([userDefaults objectForKey:key] == NULL) {
			NSObject *val = [pref objectForKey:@"DefaultValue"];
			[userDefaults setObject:val forKey:key];
			
			NSLog(@"initialized setting %@ to default: %@", key, val);
		}
	}
	
	[userDefaults synchronize];
	
	/* load search engines */
	_searchEngines = [NSDictionary dictionaryWithContentsOfFile:[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"SearchEngines.plist"]];
}

@end
