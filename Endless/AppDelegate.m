/*
 * Endless
 * Copyright (c) 2014-2017 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "Bookmark.h"
#import "HTTPSEverywhere.h"
#import <Tor/Tor.h>
#import "URLInterceptor.h"

#import "UIResponder+FirstResponder.h"

@implementation AppDelegate
{
	NSMutableArray *_keyCommands;
	NSMutableArray *_allKeyBindings;
	NSArray *_allCommandsAndKeyBindings;
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	@try {
		NSURL *resourceURL = [[NSBundle mainBundle] URLForResource:@"fabric.apikey" withExtension:nil];
		if (resourceURL) {
			NSString *fabricAPIKey = [[NSString stringWithContentsOfURL:resourceURL usedEncoding:nil error:nil] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			CrashlyticsKit.delegate = self;
			[Crashlytics startWithAPIKey:fabricAPIKey];
		} else {
			NSLog(@"[AppDelegate] no fabric.apikey found, not enabling fabric");
		}
	}
	@catch (NSException *e) {
		NSLog(@"[AppDelegate] failed setting up fabric: %@", e);
	}
	
	[self initializeDefaults];

#ifdef USE_DUMMY_URLINTERCEPTOR
	[NSURLProtocol registerClass:[DummyURLInterceptor class]];
#else
	[NSURLProtocol registerClass:[URLInterceptor class]];
#endif

	self.hstsCache = [HSTSCache retrieve];
	self.cookieJar = [[CookieJar alloc] init];
	[Bookmark retrieveList];
	
	/* handle per-version upgrades or migrations */
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	long lastBuild = [userDefaults integerForKey:@"last_build"];
	
	NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
	f.numberStyle = NSNumberFormatterDecimalStyle;
	long thisBuild = [[f numberFromString:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]] longValue];
	
	if (lastBuild != thisBuild) {
		NSLog(@"migrating from build %ld -> %ld", lastBuild, thisBuild);
		[HostSettings migrateFromBuild:lastBuild toBuild:thisBuild];
		
		[userDefaults setInteger:thisBuild forKey:@"last_build"];
		[userDefaults synchronize];
	}
	
	self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	self.window.backgroundColor = [UIColor groupTableViewBackgroundColor];
	self.window.rootViewController = [[WebViewController alloc] init];
	self.window.rootViewController.restorationIdentifier = @"WebViewController";
	
	return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[self.window makeKeyAndVisible];

	TORConfiguration *conf = [[TORConfiguration alloc] init];
	conf.cookieAuthentication = [NSNumber numberWithBool:YES];
	conf.dataDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory()];
	conf.arguments = [NSArray arrayWithObjects:
		@"--ignore-missing-torrc",
		@"--clientonly", @"1",
		@"--socksport", @"39050",
		@"--controlport", @"127.0.0.1:39060",
		@"--log", @"notice stdout",
		nil];

	TORThread *torThread = [[TORThread alloc] initWithConfiguration:conf];
	[torThread start];



	double delayInSeconds = 1.0;
	dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
	dispatch_after(popTime, dispatch_get_main_queue(), ^(void){

		NSURL *cookieURL = [[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:@"control_auth_cookie"];
		NSData *cookie = [NSData dataWithContentsOfURL:cookieURL];
		TORController *controller = [[TORController alloc] initWithSocketHost:@"127.0.0.1" port:39060];

		NSError *connErr;
		[controller connect:&connErr];

		// TODO: retry connection if we failed

		[controller authenticateWithData:cookie completion:^(BOOL success, NSError *error) {

			if (success) {
				id boostrapObserver = [controller addObserverForStatusEvents:^BOOL(NSString * _Nonnull type, NSString * _Nonnull severity, NSString * _Nonnull action, NSDictionary<NSString *,NSString *> * _Nullable arguments) {
						if ([type isEqualToString:@"STATUS_CLIENT"] && [action isEqualToString:@"BOOTSTRAP"]) {
							NSInteger progress = [[arguments valueForKey:@"PROGRESS"] integerValue];
							NSLog(@"PROGRESS: %ld", progress);

							if (progress == 100) {
								// Clean up.
								[controller removeObserver:boostrapObserver];
							}
							return YES;
						}
						return NO;
				}];

				/*********************/
				id observer = [controller addObserverForCircuitEstablished:^(BOOL established) {
					if (established) {
						// Clean up.
						[controller removeObserver:observer];
						return;
					}
				}];
				/*********************/
				/*
				[controller addObserverForStatusEvents:^BOOL(NSString * _Nonnull type, NSString * _Nonnull severity, NSString * _Nonnull action, NSDictionary<NSString *,NSString *> * _Nullable arguments) {
						NSLog(@"ZZZZ: %@ - %@ - %@", type, severity, action);
						return YES;
				}];
				*/
				/*********************/

			} else {
				NSLog(@"ZZZZ control port error: %@", error);
			}
		}];

	});

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
#ifdef TRACE
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

- (BOOL)application:(UIApplication *)application shouldAllowExtensionPointIdentifier:(NSString *)extensionPointIdentifier {
	if ([extensionPointIdentifier isEqualToString:UIApplicationKeyboardExtensionPointIdentifier]) {
		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
		return [userDefaults boolForKey:@"third_party_keyboards"];
	}
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

- (NSArray<UIKeyCommand *> *)keyCommands
{
	if (!_keyCommands) {
		_keyCommands = [[NSMutableArray alloc] init];
		
		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:@"Go Back"]];
		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputRightArrow modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:@"Go Forward"]];

		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"b" modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:@"Show Bookmarks"]];

		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"l" modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:@"Focus URL Field"]];

		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"t" modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:@"Create New Tab"]];
		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"w" modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:@"Close Tab"]];

		for (int i = 1; i <= 10; i++)
			[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:[NSString stringWithFormat:@"%d", (i == 10 ? 0 : i)] modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:[NSString stringWithFormat:@"Switch to Tab %d", i]]];
	}
	
	if (!_allKeyBindings) {
		_allKeyBindings = [[NSMutableArray alloc] init];
		const long modPermutations[] = {
					     UIKeyModifierAlphaShift,
					     UIKeyModifierShift,
					     UIKeyModifierControl,
					     UIKeyModifierAlternate,
					     UIKeyModifierCommand,
					     UIKeyModifierCommand | UIKeyModifierAlternate,
					     UIKeyModifierCommand | UIKeyModifierControl,
					     UIKeyModifierControl | UIKeyModifierAlternate,
					     UIKeyModifierControl | UIKeyModifierCommand,
					     UIKeyModifierControl | UIKeyModifierAlternate | UIKeyModifierCommand,
					     kNilOptions,
		};

		NSString *chars = @"`1234567890-=\b\tqwertyuiop[]\\asdfghjkl;'\rzxcvbnm,./ ";
		for (int j = 0; j < sizeof(modPermutations); j++) {
			for (int i = 0; i < [chars length]; i++) {
				NSString *c = [chars substringWithRange:NSMakeRange(i, 1)];

				[_allKeyBindings addObject:[UIKeyCommand keyCommandWithInput:c modifierFlags:modPermutations[j] action:@selector(handleKeyboardShortcut:)]];
			}
		
			[_allKeyBindings addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow modifierFlags:modPermutations[j] action:@selector(handleKeyboardShortcut:)]];
			[_allKeyBindings addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputDownArrow modifierFlags:modPermutations[j] action:@selector(handleKeyboardShortcut:)]];
			[_allKeyBindings addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputLeftArrow modifierFlags:modPermutations[j] action:@selector(handleKeyboardShortcut:)]];
			[_allKeyBindings addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputRightArrow modifierFlags:modPermutations[j] action:@selector(handleKeyboardShortcut:)]];
			[_allKeyBindings addObject:[UIKeyCommand keyCommandWithInput:UIKeyInputEscape modifierFlags:modPermutations[j] action:@selector(handleKeyboardShortcut:)]];
		}
		
		_allCommandsAndKeyBindings = [_keyCommands arrayByAddingObjectsFromArray:_allKeyBindings];
	}
	
	/* if settings are up or something else, ignore shortcuts */
	if (![[self topViewController] isKindOfClass:[WebViewController class]])
		return nil;
	
	id cur = [UIResponder currentFirstResponder];
	if (cur == nil || [NSStringFromClass([cur class]) isEqualToString:@"UIWebView"])
		return _allCommandsAndKeyBindings;
	else {
#ifdef TRACE_KEYBOARD_INPUT
		NSLog(@"[AppDelegate] current first responder is a %@, only passing shortcuts", NSStringFromClass([cur class]));
#endif
		return _keyCommands;
	}
}

- (void)handleKeyboardShortcut:(UIKeyCommand *)keyCommand
{
	if ([keyCommand modifierFlags] == UIKeyModifierCommand) {
		if ([[keyCommand input] isEqualToString:@"b"]) {
			[[self webViewController] showBookmarksForEditing:NO];
			return;
		}

		if ([[keyCommand input] isEqualToString:@"l"]) {
			[[self webViewController] focusUrlField];
			return;
		}
		
		if ([[keyCommand input] isEqualToString:@"t"]) {
			[[self webViewController] addNewTabForURL:nil forRestoration:NO withCompletionBlock:^(BOOL finished) {
				[[self webViewController] focusUrlField];
			}];
			return;
		}
		
		if ([[keyCommand input] isEqualToString:@"w"]) {
			[[self webViewController] removeTab:[[[self webViewController] curWebViewTab] tabIndex]];
			return;
		}
		
		if ([[keyCommand input] isEqualToString:UIKeyInputLeftArrow]) {
			[[[self webViewController] curWebViewTab] goBack];
			return;
		}
		
		if ([[keyCommand input] isEqualToString:UIKeyInputRightArrow]) {
			[[[self webViewController] curWebViewTab] goForward];
			return;
		}

		for (int i = 0; i <= 9; i++) {
			if ([[keyCommand input] isEqualToString:[NSString stringWithFormat:@"%d", i]]) {
				[[self webViewController] switchToTab:[NSNumber numberWithInt:(i == 0 ? 9 : i - 1)]];
				return;
			}
		}
	}
	
	if ([self webViewController] && [[self webViewController] curWebViewTab])
		[[[self webViewController] curWebViewTab] handleKeyCommand:keyCommand];
}

- (UIViewController *)topViewController
{
	return [self topViewController:[UIApplication sharedApplication].keyWindow.rootViewController];
}

- (UIViewController *)topViewController:(UIViewController *)rootViewController
{
	if (rootViewController.presentedViewController == nil)
		return rootViewController;
	
	if ([rootViewController.presentedViewController isMemberOfClass:[UINavigationController class]]) {
		UINavigationController *navigationController = (UINavigationController *)rootViewController.presentedViewController;
		UIViewController *lastViewController = [[navigationController viewControllers] lastObject];
		return [self topViewController:lastViewController];
	}
	
	UIViewController *presentedViewController = (UIViewController *)rootViewController.presentedViewController;
	return [self topViewController:presentedViewController];
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
