/*
 * Endless
 * Copyright (c) 2014-2018 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <AVFoundation/AVFoundation.h>

#import "AppDelegate.h"
#import "HTTPSEverywhere.h"
#import "HostSettings.h"
#import "DownloadHelper.h"

#import "UIResponder+FirstResponder.h"

#import "OBRootViewController.h"
#import "OnionBrowser-Swift.h"

@implementation AppDelegate
{
	NSMutableArray *_keyCommands;
	NSMutableArray *_allKeyBindings;
	NSArray *_allCommandsAndKeyBindings;

	BOOL inStartupPhase;

	UIAlertController *authAlertController;
}


# pragma mark: - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	inStartupPhase = YES;

	self.socksProxyPort = 39050;
	self.sslCertCache = [[NSCache alloc] init];
	self.certificateAuthentication = [[CertificateAuthentication alloc] init];

	[JAHPAuthenticatingHTTPProtocol setDelegate:self];
	[JAHPAuthenticatingHTTPProtocol start];

	self.hstsCache = [HSTSCache retrieve];
	self.cookieJar = [[CookieJar alloc] init];

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
	self.window.rootViewController = [[OBRootViewController alloc] init];
	self.window.rootViewController.restorationIdentifier = @"OBRootViewController";

	[self adjustMuteSwitchBehavior];
	
    [Migration migrate];

    Boolean didFirstRunBookmarks = [userDefaults boolForKey:@"did_first_run_bookmarks"];
    if (!didFirstRunBookmarks) {
        if (Bookmark.all.count == 0) { // our first run of Onion Browser 2, but did we migrate any bookmarks from previous versions?
			[Bookmark addWithName:@"DuckDuckGo Search Engine (onion)" url:@"https://3g2upl4pq6kufc4m.onion/"];
			[Bookmark addWithName:@"The Tor Project (onion)" url:@"http://expyuzz4wqqyqhjn.onion/"];
			[Bookmark addWithName:@"Freedom of the Press Foundation" url:@"https://freedom.press/"];
			[Bookmark addWithName:@"ProPublica (onion)" url:@"https://www.propub3r6espa33w.onion/"];
			[Bookmark addWithName:@"New York Times (onion)" url:@"https://mobile.nytimes3xbfgragh.onion/"];
			[Bookmark addWithName:@"Facebook (Onion)" url:@"https://m.facebookcorewwwi.onion/"];
			[Bookmark addWithName:@"Onion Browser official site (onion)" url:@"http://tigas3l7uusztiqu.onion/onionbrowser/"];
			[Bookmark addWithName:@"Mike Tigas, Onion Browser author (onion)" url:@"http://tigas3l7uusztiqu.onion/"];
            [Bookmark store];
        }
        [userDefaults setBool:YES forKey:@"did_first_run_bookmarks"];
        [userDefaults synchronize];
    }

	[DownloadHelper deleteDownloadsDirectory];

    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	[self.window makeKeyAndVisible];

	if (launchOptions != nil && [launchOptions objectForKey:UIApplicationLaunchOptionsShortcutItemKey]) {
		[self handleShortcut:[launchOptions objectForKey:UIApplicationLaunchOptionsShortcutItemKey]];
	}
	
	return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
	[application ignoreSnapshotOnNextApplicationLaunch];
	[[self webViewController] viewIsNoLongerVisible];

	[BlurredSnapshot create];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
	if (![self areTesting]) {
		[HostSettings persist];
		[[self hstsCache] persist];
	}
	
	[TabSecurity handleBackgrounding];

	[application ignoreSnapshotOnNextApplicationLaunch];

    if (OnionManager.shared.state != TorStateStopped) {
        [OnionManager.shared stopTor];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
	[BlurredSnapshot remove];

	[[self webViewController] viewIsVisible];

    if (!inStartupPhase && OnionManager.shared.state != TorStateStarted && OnionManager.shared.state != TorStateConnected) {
        // TODO: actually use UI instead of silently trying to restart Tor.
        [OnionManager.shared startTorWithDelegate:nil];

//        if ([self.window.rootViewController class] != [OBRootViewController class]) {
//                self.window.rootViewController = [[OBRootViewController alloc] init];
//                self.window.rootViewController.restorationIdentifier = @"OBRootViewController";
//        }
    }
    else {
		// During app startup, we don't start Tor from here, but from
		// OBRootViewController in order to catch the delegate callback for progress.
		inStartupPhase = NO;
//        [[self webViewController] viewIsVisible];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
	/* this definitely ends our sessions */
	[[self cookieJar] clearAllNonWhitelistedData];

	[DownloadHelper deleteDownloadsDirectory];

	[application ignoreSnapshotOnNextApplicationLaunch];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
#ifdef TRACE
	NSLog(@"[AppDelegate] request to open url: %@", url);
#endif

	if ([url.scheme.lowercaseString isEqualToString:@"onionhttp"])
	{
		NSURLComponents *urlc = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:YES];
		urlc.scheme = @"http";
		url = urlc.URL;
	}
	else if ([url.scheme.lowercaseString isEqualToString:@"onionhttps"])
	{
		NSURLComponents *urlc = [[NSURLComponents alloc] initWithURL:url resolvingAgainstBaseURL:YES];
		urlc.scheme = @"https";
		url = urlc.URL;
	}

	// In case, a modal view controller is overlaying the WebViewController,
	// we need to close it *before* adding a new tab. Otherwise, the UI will
	// be broken on iPhone-X-type devices: The address field will be in the
	// notch area.
	if (self.webViewController.presentedViewController != nil)
	{
		[self.webViewController dismissViewControllerAnimated:YES completion:^{
			[self.webViewController addNewTabForURL:url];
		}];
	}
	// If there's no modal view controller, however, the completion block would
	// never be called.
	else {
		[self.webViewController addNewTabForURL:url];
	}

	return YES;
}

- (void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler
{
	[self handleShortcut:shortcutItem];
	completionHandler(YES);
}

- (BOOL)application:(UIApplication *)application shouldAllowExtensionPointIdentifier:(NSString *)extensionPointIdentifier {
	if ([extensionPointIdentifier isEqualToString:UIApplicationKeyboardExtensionPointIdentifier]) {
		return Settings.thirdPartyKeyboards;
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

	return !TabSecurity.isClearOnBackground;
}


# pragma mark: - Endless

- (NSArray<UIKeyCommand *> *)keyCommands
{
	if (!_keyCommands) {
		_keyCommands = [[NSMutableArray alloc] init];
		
		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"[" modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:NSLocalizedString(@"Go Back", nil)]];
		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"]" modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:NSLocalizedString(@"Go Forward", nil)]];

		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"b" modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:NSLocalizedString(@"Show Bookmarks", nil)]];

		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"l" modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:NSLocalizedString(@"Focus URL Field", nil)]];

		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"t" modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:NSLocalizedString(@"Create New Tab", nil)]];
		[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:@"w" modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:NSLocalizedString(@"Close Tab", nil)]];

		for (int i = 1; i <= 10; i++)
			[_keyCommands addObject:[UIKeyCommand keyCommandWithInput:[NSString stringWithFormat:@"%d", (i == 10 ? 0 : i)] modifierFlags:UIKeyModifierCommand action:@selector(handleKeyboardShortcut:) discoverabilityTitle:[NSString stringWithFormat:NSLocalizedString(@"Switch to Tab %d", nil), i]]];
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
			[self.webViewController showBookmarks];
			return;
		}

		if ([[keyCommand input] isEqualToString:@"l"]) {
			[[self webViewController] focusUrlField];
			return;
		}
		
		if ([[keyCommand input] isEqualToString:@"t"]) {
			[[self webViewController] addNewTabForURL:nil forRestoration:NO withAnimation:WebViewTabAnimationDefault withCompletionBlock:^(BOOL finished) {
				[[self webViewController] focusUrlField];
			}];
			return;
		}
		
		if ([[keyCommand input] isEqualToString:@"w"]) {
			[[self webViewController] removeTab:[[[self webViewController] curWebViewTab] tabIndex]];
			return;
		}
		
		if ([[keyCommand input] isEqualToString:@"["]) {
			[[[self webViewController] curWebViewTab] goBack];
			return;
		}
		
		if ([[keyCommand input] isEqualToString:@"]"]) {
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

- (void)handleShortcut:(UIApplicationShortcutItem *)shortcutItem
{
	if ([[shortcutItem type] containsString:@"OpenNewTab"]) {
		[[self webViewController] dismissViewControllerAnimated:YES completion:nil];
		[[self webViewController] addNewTabFromToolbar:nil];
	} else if ([[shortcutItem type] containsString:@"ClearData"]) {
		[[self webViewController] removeAllTabs];
		[[self cookieJar] clearAllNonWhitelistedData];
	} else {
		NSLog(@"[AppDelegate] need to handle action %@", [shortcutItem type]);
	}
}

- (void)adjustMuteSwitchBehavior
{
	if (Settings.muteWithSwitch) {
		/* setting AVAudioSessionCategoryAmbient will prevent audio from UIWebView from pausing already-playing audio from other apps */
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:nil];
		[[AVAudioSession sharedInstance] setActive:NO error:nil];
	} else {
		[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
	}
}


# pragma mark: Psiphon

+ (AppDelegate *)sharedAppDelegate
{
	__block AppDelegate *delegate;

	if ([NSThread isMainThread])
	{
		delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
	}
	else {
		dispatch_sync(dispatch_get_main_queue(), ^{
			delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
		});
	}
	
	return delegate;
}


# pragma mark: JAHPAuthenticatingHTTPProtocol delegate methods

#ifdef TRACE
- (void)authenticatingHTTPProtocol:(JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol logWithFormat:(NSString *)format arguments:(va_list)arguments {
	NSLog(@"[JAHPAuthenticatingHTTPProtocol] %@", [[NSString alloc] initWithFormat:format arguments:arguments]);
}
#endif

- (BOOL)authenticatingHTTPProtocol:( JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol canAuthenticateAgainstProtectionSpace:( NSURLProtectionSpace *)protectionSpace {
	return ([protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPDigest]
			|| [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodHTTPBasic]);
}

- (JAHPDidCancelAuthenticationChallengeHandler)authenticatingHTTPProtocol:( JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol didReceiveAuthenticationChallenge:( NSURLAuthenticationChallenge *)challenge {
	NSURLCredential *nsuc;

	/* if we have existing credentials for this realm, try it first */
	if ([challenge previousFailureCount] == 0) {
		NSDictionary *d = [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:[challenge protectionSpace]];
		if (d != nil) {
			for (id u in d) {
				nsuc = [d objectForKey:u];
				break;
			}
		}
	}

	/* no credentials, prompt the user */
	if (nsuc == nil) {
		dispatch_async(dispatch_get_main_queue(), ^{
			self->authAlertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Authentication Required", @"HTTP authentication alert title") message:@"" preferredStyle:UIAlertControllerStyleAlert];

			if ([[challenge protectionSpace] realm] != nil && ![[[challenge protectionSpace] realm] isEqualToString:@""])
			[self->authAlertController setMessage:[NSString stringWithFormat:@"%@: \"%@\"", [[challenge protectionSpace] host], [[challenge protectionSpace] realm]]];
			else
			[self->authAlertController setMessage:[[challenge protectionSpace] host]];

			[self->authAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				textField.placeholder = NSLocalizedString(@"User Name", "HTTP authentication alert user name input title");
			}];

			[self->authAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
				textField.placeholder = NSLocalizedString(@"Password", @"HTTP authentication alert password input title");
				textField.secureTextEntry = YES;
			}];

			[self->authAlertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
				[[challenge sender] cancelAuthenticationChallenge:challenge];
				[authenticatingHTTPProtocol.client URLProtocol:authenticatingHTTPProtocol didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:@{ ORIGIN_KEY: @YES }]];
			}]];

			[self->authAlertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Log In", @"HTTP authentication alert log in button action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
				UITextField *login = self->authAlertController.textFields.firstObject;
				UITextField *password = self->authAlertController.textFields.lastObject;

				NSURLCredential *nsuc = [[NSURLCredential alloc] initWithUser:[login text] password:[password text] persistence:NSURLCredentialPersistenceForSession];

				// We only want one set of credentials per [challenge protectionSpace]
				// in case we stored incorrect credentials on the previous login attempt
				// Purge stored credentials for the [challenge protectionSpace]
				// before storing new ones.
				// Based on a snippet from http://www.springenwerk.com/2008/11/i-am-currently-building-iphone.html

				NSDictionary *credentialsDict = [[NSURLCredentialStorage sharedCredentialStorage] credentialsForProtectionSpace:[challenge protectionSpace]];
				if ([credentialsDict count] > 0) {
					NSEnumerator *userNameEnumerator = [credentialsDict keyEnumerator];
					id userName;

					// iterate over all usernames, which are the keys for the actual NSURLCredentials
					while (userName = [userNameEnumerator nextObject]) {
						NSURLCredential *cred = [credentialsDict objectForKey:userName];
						if(cred) {
							[[NSURLCredentialStorage sharedCredentialStorage] removeCredential:cred forProtectionSpace:[challenge protectionSpace]];
						}
					}
				}

				[[NSURLCredentialStorage sharedCredentialStorage] setCredential:nsuc forProtectionSpace:[challenge protectionSpace]];

				[authenticatingHTTPProtocol resolvePendingAuthenticationChallengeWithCredential:nsuc];
			}]];

			[[[AppDelegate sharedAppDelegate] webViewController] presentViewController:self->authAlertController animated:YES completion:nil];
		});
	}
	else {
		[[NSURLCredentialStorage sharedCredentialStorage] setCredential:nsuc forProtectionSpace:[challenge protectionSpace]];
		[authenticatingHTTPProtocol resolvePendingAuthenticationChallengeWithCredential:nsuc];
	}

	return nil;

}

- (void)authenticatingHTTPProtocol:( JAHPAuthenticatingHTTPProtocol *)authenticatingHTTPProtocol didCancelAuthenticationChallenge:( NSURLAuthenticationChallenge *)challenge {
	if(authAlertController) {
		if (authAlertController.isViewLoaded && authAlertController.view.window) {
			[authAlertController dismissViewControllerAnimated:NO completion:nil];
		}
	}
}

@end
