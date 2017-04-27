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
        self.introVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.conctVC = [[ConnectingViewController alloc] init];
        self.conctVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        self.errorVC = [[ErrorViewController alloc] init];
        self.errorVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    }

    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear: animated];

    [self presentViewController: self.introVC animated: animated completion: nil];
}

- (void)introFinished:(BOOL)useBridge
{
    [[OnionManager singleton] startTorWithDelegate:self];

    // Tor doesn't always come up right away, so put a tiny delay.
    // TODO: actually find a solution for race condition
    [NSTimer scheduledTimerWithTimeInterval:1.0f repeats:NO block:^(NSTimer * _Nonnull timer) {
        [_conctVC connectingStarted];
    }];


    [self.introVC presentViewController:self.conctVC animated:YES completion:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"OBROOTVIEWCONTROLLER Tor fail guard - has it started? %d", self.torStarted);

        if (!self.torStarted)
        {
            [self.errorVC updateProgress:self.progress];
            [self.conctVC presentViewController:self.errorVC animated:YES completion:nil];
        }
    });
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


// MARK: - POEDelegate callbacks

// POEDelegate callback when user clicks "Continue"
- (void)userFinishedConnecting
{
    // This is probably not the right way to do this.
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.webViewController =[[WebViewController alloc] init];

    [self dismissViewControllerAnimated: true completion: nil];
    [appDelegate.webViewController viewIsVisible];
}

@end
