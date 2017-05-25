/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import "OBRootViewController.h"
#import "AppDelegate.h"
#import "BridgeViewController.h"
#import "OBSettingsConstants.h"

#ifdef __OBJC__
#import "OnionBrowser-Swift.h"
#import <Tor/Tor.h>
#endif

@implementation OBRootViewController

- (id)init
{
    if (self = [super initWithNibName: @"LaunchScreen" bundle: [NSBundle bundleForClass: [OBRootViewController classForCoder]]])
    {
        self.introVC = [[IntroViewController alloc] init];
        self.introVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
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

        [self.settings setBool:NO forKey:DID_INTRO];
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

-(void) torConnProgress: (NSInteger)progress {
    NSLog(@"OBROOTVIEWCONTROLLER received tor progress callback: %ld", (long)progress);

    self.progress = (float)progress / 100;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.conctVC updateProgress:self.progress];
    });
}

-(void) torConnFinished {
    self.torStarted = YES;

    NSLog(@"OBROOTVIEWCONTROLLER received tor connection completion callback");

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.conctVC connectingFinished];
    });
}


// MARK: - POEDelegate

/**
    Callback, after the user finished the intro and selected, if she wants to
    use a bridge or not.

    - parameter useBridge: true, if user selected to use a bridge, false, if not.
 */
- (void)introFinished:(BOOL)useBridge
{
    //[self.settings setBool:YES forKey:DID_INTRO];
    if (useBridge) {
        BridgeViewController *bridgesVC = [[BridgeViewController alloc] initWithStyle:UITableViewStyleGrouped];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bridgesVC];
        navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        
        [self.introVC presentViewController:navController animated:YES completion:nil];
    } else {
        //[self.settings setBool:[NSNumber numberWithInt:USE_BRIDGES_NONE] forKey:USE_BRIDGES];

        // Jump straight to startTor
        [self.introVC presentViewController:self.conctVC animated:YES completion:nil];
        [self startTor];
    }
}

/**
    Callback, after the user pressed the "Start Browsing" button.
 */
- (void)userFinishedConnecting
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.webViewController = [[WebViewController alloc] init];

    [self dismissViewControllerAnimated: true completion: ^{
        appDelegate.window.rootViewController = appDelegate.webViewController;
        [appDelegate.webViewController viewIsVisible];
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
    [self.settings synchronize];
    
    OnionManager *onion = [OnionManager singleton];
    
    if ([self.settings integerForKey:USE_BRIDGES] != USE_BRIDGES_NONE) {
        // Take default config, add the built-in obfs4 bridges, and turn on "usebridges 1"
        NSArray<NSString *> *args = [[onion torConf] arguments];
        args = [args arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"--usebridges", @"1", nil]];
        
        NSLog(@"use_bridges = %ld", (long)[self.settings integerForKey:USE_BRIDGES]);
        
        if ([self.settings integerForKey:USE_BRIDGES] == USE_BRIDGES_OBFS4) {
            args = [args arrayByAddingObjectsFromArray:[OnionManager bridgeLinesToArgsWithBridgeLines:[OnionManager bridgeBuiltInObfs4Bridges]]];
        } else if ([self.settings integerForKey:USE_BRIDGES] == USE_BRIDGES_MEEKAMAZON) {
            args = [args arrayByAddingObjectsFromArray:[OnionManager bridgeLinesToArgsWithBridgeLines:[OnionManager bridgeBuiltInMeekAmazonBridges]]];
        } else if ([self.settings integerForKey:USE_BRIDGES] == USE_BRIDGES_MEEKAZURE) {
            args = [args arrayByAddingObjectsFromArray:[OnionManager bridgeLinesToArgsWithBridgeLines:[OnionManager bridgeBuiltInMeekAzureBridges]]];
        } else if ([self.settings integerForKey:USE_BRIDGES] == USE_BRIDGES_CUSTOM) {
            args = [args arrayByAddingObjectsFromArray:[OnionManager bridgeLinesToArgsWithBridgeLines:[self.settings arrayForKey:CUSTOM_BRIDGES]]];
        }
        NSLog(@"\n\n%@\n\n",args);
        [[onion torConf] setArguments:args];
    }
    
    [onion startTorWithDelegate:self];
    
    // Tor doesn't always come up right away, so put a tiny delay.
    // TODO: actually find a solution for race condition
    [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer * _Nonnull timer) {
        [_conctVC connectingStarted];
    }];

    // Tor doesn't always come up right away, so put a tiny delay.
    // TODO: actually find a solution for race condition
    [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer * _Nonnull timer) {
        [self.conctVC connectingStarted];
    }];

    // Show error to user, when, after 30 seconds, Tor has still not started.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"OBROOTVIEWCONTROLLER Tor fail guard - has it started? %d", self.torStarted);

        if (!self.torStarted)
        {
            // Show intro again, next time, so user can choose a bridge.
            [self.settings setBool:NO forKey:DID_INTRO];
            [self.settings synchronize];

            [self.errorVC updateProgress:self.progress];
            [self.conctVC presentViewController:self.errorVC animated:YES completion:nil];
        }
    });
}


@end
