/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import "OBRootViewController.h"
#import "AppDelegate.h"

#ifdef __OBJC__
#import "OnionBrowser-Swift.h"
#endif


@implementation OBRootViewController

- (id)init
{
    if (self = [super initWithNibName: @"LaunchScreen" bundle: [NSBundle bundleForClass: [OBRootViewController classForCoder]]])
    {
        self.introVC = [[IntroViewController alloc] init];
        self.conctVC = [[ConnectingViewController alloc] init];
        self.errorVC = [[ErrorViewController alloc] init];
    }

    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear: animated];

    if (!self.nextVC)
    {
        self.nextVC = self.introVC;
    }

    [self presentViewController: self.nextVC animated: animated completion: nil];
}

- (void)introFinished:(BOOL)useBridge
{
    self.nextVC = self.conctVC;

    [[OnionManager singleton] startTorWithDelegate:self];

    // Tor doesn't always come up right away, so put a tiny delay.
    // TODO: actually find a solution for race condition
    [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer * _Nonnull timer) {
        [_conctVC connectionStarted];
    }];


    [self dismissViewControllerAnimated: true completion: nil];
}

// MARK: - OnionManagerDelegate callbacks
// OnionManager will call these when it receives progress indication from
// the underlying Tor process. We mostly don't really use this here, instead
// passing the info along to `conctVC`.

-(void) torConnProgress: (NSInteger)progress {
    if (self.nextVC == self.conctVC) {
        NSLog(@"OBROOTVIEWCONTROLLER received tor progress callback: %ld", (long)progress);
        [self.conctVC connectionProgressWithProgress:progress];
    }
}

-(void) torConnFinished {
    NSLog(@"OBROOTVIEWCONTROLLER received tor connection completion callback");
    [self.conctVC connectionFinished];
}


// MARK: - POEDelegate callbacks

// POEDelegate callback when user clicks "Continue"
- (void)userFinishedConnecting
{
    // This is probably not the right way to do this.
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.webViewController =[[WebViewController alloc] init];
    self.nextVC = appDelegate.webViewController;

    [self dismissViewControllerAnimated: true completion: nil];
    [appDelegate.webViewController viewIsVisible];
}

@end
