// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <XCTest/XCTest.h>
#import "AppDelegate.h"

@interface OnionBrowserTests : XCTestCase
@property (nonatomic, readwrite, weak) AppDelegate *appDelegate;
@property (nonatomic, readwrite, weak) TorController *tor;
@end

@implementation OnionBrowserTests

- (void)setUp
{
    [super setUp];
    self.appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.tor = self.appDelegate.tor;
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAppDelegate{
    //test that the appdelegate is not null
    XCTAssertNotNil(self.appDelegate, @"Cannot find appDelegate");
}

- (void)testTorConnection {
    NSURL *url = [NSURL URLWithString:@"https://check.torproject.org/"];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];

    NSLog(@"Fetching https://check.torproject.org/ and looking for 'Congratulations.' text.");

    for (int i=0; i<6; i++) {
        [NSThread sleepForTimeInterval:2.5f];
        NSData *res = [NSURLConnection  sendSynchronousRequest:req returningResponse:NULL error:NULL];
        NSString *result = [[NSString alloc] initWithData:res encoding:NSUTF8StringEncoding];

        NSRange r = [result rangeOfString:@"Congratulations."];
        if (r.location != NSNotFound) {
            NSLog(@"Found 'Congratulations.' text. Assuming we are connected to Tor. Passing test.");
            return;
        }
    }
    XCTFail(@"Did not get correct 'check.torproject.org' response after 6 tries.");
}

@end
