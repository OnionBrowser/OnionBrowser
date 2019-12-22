/*
 * Onion Browser
 * Copyright (c) 2012-2018, Tigas Ventures, LLC (Mike Tigas)
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import "OBRootViewController.h"
#import "AppDelegate.h"
#import "OBSettingsConstants.h"

#ifdef __OBJC__
#import "OnionBrowser-Swift.h"
#import <Tor/Tor.h>
#endif

@implementation OBRootViewController

- (id)init
{
	if (self = [super init])
    {
		self.view.backgroundColor = UIColor.poeAccent;

        self.introVC = [[IntroViewController alloc] init];
        self.introVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

        NSDictionary<NSNumber *,NSString *> *builtInBridges;
		builtInBridges = @{[NSNumber numberWithInteger:USE_BRIDGES_OBFS4]: @"obfs4",
						   [NSNumber numberWithInteger:USE_BRIDGES_MEEKAZURE]: @"meek-azure"};

        self.bridgeVC = [BridgeSelectViewController
                         instantiateWithCurrentId:[NSUserDefaults.standardUserDefaults integerForKey:USE_BRIDGES]
                         noBridgeId:[NSNumber numberWithInteger:USE_BRIDGES_NONE]
                         providedBridges:builtInBridges
                         customBridgeId:[NSNumber numberWithInteger:USE_BRIDGES_CUSTOM]
                         customBridges:[NSUserDefaults.standardUserDefaults stringArrayForKey:CUSTOM_BRIDGES]
                         delegate:nil];
        
        self.conctVC = [[ConnectingViewController alloc] init];
        self.conctVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.errorVC = [[ErrorViewController alloc] init];
        self.errorVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;

        self.settings = [NSUserDefaults standardUserDefaults];

        self.isStartup = YES;
    }

    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear: animated];

    // Need this check, otherwise, #viewDidAppear will be called again just before we switch to
    // the Endless browser.
    if (self.isStartup)
    {
        self.isStartup = NO;

         // Enable this for debugging:
//        [self.settings setBool:NO forKey:DID_INTRO];
        if ([self.settings boolForKey:DID_INTRO])
        {
            self.conctVC.autoClose = YES;
            [self presentViewController: self.conctVC animated: animated completion: nil];
            [self startTor];
        }
        else {
            [self presentViewController: self.introVC animated: animated completion: nil];
        }
        [self.settings synchronize];
    }
}

// MARK: - OnionManagerDelegate callbacks
// OnionManager will call these when it receives progress indication from
// the underlying Tor process. We mostly don't really use this here, instead
// passing the info along to `conctVC`.

- (void)torConnProgress: (NSInteger)progress
{
    NSLog(@"[%@] received tor progress callback: %ld", [self class], (long)progress);

    self.progress = (float)progress / 100;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.conctVC updateProgress:self.progress];
    });
}

- (void)torConnFinished
{
    NSLog(@"[%@] received tor connection completion callback", [self class]);

    if (!self.ignoreTor)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.conctVC connectingFinished];

			if (![NSUserDefaults.standardUserDefaults boolForKey:@"did_first_run_bookmarks"])
			{
				[Bookmark firstRunSetup];

				[NSUserDefaults.standardUserDefaults setBool:YES forKey:@"did_first_run_bookmarks"];
			}
        });
    }
}

-(void)torConnError
{
    if (!self.ignoreTor)
    {
        NSLog(@"[%@] Tor didn't start!", [self class]);

        [self.conctVC presentViewController:self.errorVC animated:YES completion:nil];
    }
}


// MARK: - POEDelegate

/**
    Callback, after the user finished the intro and selected, if she wants to
    use a bridge or not.

    - parameter useBridge: true, if user selected to use a bridge, false, if not.
 */
- (void)introFinished:(BOOL)useBridge
{
    [self.settings setBool:YES forKey:DID_INTRO];

    if (useBridge) {
        [self.introVC presentViewController:self.bridgeVC animated:YES completion:nil];
        return;
    }

    [self.settings setInteger:USE_BRIDGES_NONE forKey:USE_BRIDGES];

    // Jump straight to startTor
    [self.introVC presentViewController:self.conctVC animated:YES completion:nil];
    [self startTor];
}

/**
     Receive this callback, after the user finished the bridges configuration.

     - parameter bridgesId: the selected ID of the list you gave in the constructor of
     BridgeSelectViewController.
     - parameter customBridges: the list of custom bridges the user configured.
 */
- (void)bridgeConfigured:(NSInteger)bridgesId customBridges:(NSArray *)customBridges
{
    [self.settings setInteger:bridgesId forKey:USE_BRIDGES];
    [self.settings setObject:customBridges forKey:CUSTOM_BRIDGES];

    if (self.conctVC.presentingViewController)
    {
        // Already showing - do connection again from beginning.
        [self startTor];
    }
    else {
        // Not showing - present the ConnectingViewController and start connecting afterwards.
        [self.introVC presentViewController:self.conctVC animated:YES completion:^{
            [self startTor];
        }];
    }
}

/**
     Receive this callback, when the user pressed the gear icon in the ConnectingViewController.

     This probably means, the connection doesn't work and the user wants to configure bridges.

     Cancel the connection here and show the BridgeSelectViewController afterwards.
 */
- (void)changeSettings
{
    self.ignoreTor = YES;
    [self.conctVC presentViewController:self.bridgeVC animated:YES completion:nil];
}

/**
    Callback, after the user pressed the "Start Browsing" button.
 */
- (void)userFinishedConnecting
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.browsingUi = [[BrowsingViewController alloc] init];

    [self dismissViewControllerAnimated: YES completion: ^{
        appDelegate.window.rootViewController = appDelegate.browsingUi;

		[TabSecurity restore];

		[appDelegate.browsingUi becomesVisible];
    }];
}

/**
     Callback, when the user changed the locale.
 */
- (void)localeUpdated:(NSString *)localeId
{
    [self.settings setObject:localeId forKey:LOCALE];
    [self.settings synchronize];
}

// MARK: - Private methods

/**
    Start OnionManager, tell ConnectingViewController, that connecting is now started,
    start a guard thread, which shows an ErrorViewController, when Tor doesn't come up after 30
    seconds.
 */
- (void) startTor
{
    self.ignoreTor = NO;
    [self.settings synchronize];
    
    OnionManager *onion = OnionManager.shared;
    [onion setBridgeConfigurationWithBridgesId:[self.settings integerForKey:USE_BRIDGES]
                                 customBridges:[self.settings arrayForKey:CUSTOM_BRIDGES]];
    [onion startTorWithDelegate:self];

    [self.conctVC connectingStarted];
}

@end
