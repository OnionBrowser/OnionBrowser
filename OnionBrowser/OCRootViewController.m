//
//  OCRootViewController.m
//  POE
//
//  Created by Benjamin Erhart on 06.04.17.
//  Copyright © 2017 CocoaPods. All rights reserved.
//

#import "OCRootViewController.h"
#import "AppDelegate.h"

#ifdef __OBJC__
#import "OnionBrowser-Swift.h"
#endif


@implementation OCRootViewController

- (id)init
{
    if (self = [super initWithNibName: @"LaunchScreen" bundle: [NSBundle bundleForClass: [OCRootViewController classForCoder]]])
    {
        self.introVC = [[IntroViewController alloc] init];
        self.conctVC = [[ConnectingViewController alloc] init];
        self.errorVC = [[ErrorViewController alloc] init];

				self.onionMgr = [OnionManager singleton];
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

		/*
    if (self.nextVC == self.conctVC)
    {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.conctVC done];
        });
    }
		*/
}

- (void)introFinished:(BOOL)useBridge
{
		NSLog(@"INTRO FINISHED, NOW CONNECTING");
    self.nextVC = self.conctVC;
		[self.onionMgr.class startTorWithCallback:^{
			NSLog(@"CONNECTION FINISHED, CALLING CONCTVC.DONE");
			[self.conctVC done];
		}];

    [self dismissViewControllerAnimated: true completion: nil];
}

// POEDelegate
- (void)connectingFinished
{
		NSLog(@"POEDELEGATE.CONNECTINGFINISHED WAS CALLED");

		// This is probably not the right way to do this.
		AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		appDelegate.webViewController =[[WebViewController alloc] init];
		self.nextVC = appDelegate.webViewController;
		//appDelegate.window.rootViewController.restorationIdentifier = @"WebViewController";

    [self dismissViewControllerAnimated: true completion: nil];
		[appDelegate.webViewController viewIsVisible];


}

@end
