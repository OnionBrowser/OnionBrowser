// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "TorWrapper.h"
#import "AppDelegate.h"

@implementation TorWrapper
@synthesize tor;

//-(NSData *)readTorCookie {
//    /* We have the CookieAuthentication ControlPort method set up, so Tor
//     * will create a "control_auth_cookie" in the data dir. The contents of this
//     * file is the data that AppDelegate will use to communicate back to Tor. */
//    NSString *tmpDir = NSTemporaryDirectory();
//    NSString *control_auth_cookie = [tmpDir stringByAppendingPathComponent:@"control_auth_cookie"];
//
//    NSData *cookie = [[NSData alloc] initWithContentsOfFile:control_auth_cookie];
//    return cookie;
//}

-(void)start {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    //NSString *base_torrc = [[NSBundle mainBundle] pathForResource:@"torrc" ofType:nil];
    NSString *base_torrc = [[[appDelegate applicationDocumentsDirectory] URLByAppendingPathComponent:@"torrc"] relativePath];
	NSString *geoip = [[NSBundle mainBundle] pathForResource:@"geoip" ofType:nil];
	NSString *geoip6 = [[NSBundle mainBundle] pathForResource:@"geoip6" ofType:nil];

    NSString *controlPortStr = [NSString stringWithFormat:@"%ld", (unsigned long)appDelegate.tor.torControlPort];
    NSString *socksPortStr = [NSString stringWithFormat:@"%ld", (unsigned long)appDelegate.tor.torSocksPort];

    //NSLog(@"%@ / %@", controlPortStr, socksPortStr);

    /**************/

	TORConfiguration *conf = [[TORConfiguration alloc] init];
	conf.cookieAuthentication = [NSNumber numberWithBool:YES];
	//conf.dataDirectory = [NSURL fileURLWithPath:NSTemporaryDirectory()];
  conf.dataDirectory = [[[appDelegate applicationLibraryDirectory] URLByAppendingPathComponent:@"Caches" isDirectory:YES] URLByAppendingPathComponent:@"tor" isDirectory:YES];

	conf.arguments = [NSArray arrayWithObjects:
					  @"--controlport", controlPortStr,
					  @"--socksport", socksPortStr,
					  @"--geoipfile", geoip,
					  @"--geoipv6file", geoip6,
					  @"--log",
#ifndef DEBUG
					  @"err file /dev/null",
#endif
#ifdef DEBUG
					  @"notice stderr",
#endif
					  @"-f", base_torrc,
					  nil];

	tor = [[TORThread alloc] initWithConfiguration:conf];
	[tor start];

}

@end
