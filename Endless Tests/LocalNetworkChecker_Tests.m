//
//  LocalNetworkChecker_Tests.m
//  Endless
//
//  Created by joshua stein on 12/22/16.
//  Copyright © 2016 jcs. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "LocalNetworkChecker.h"

@interface LocalNetworkChecker_Tests : XCTestCase

@end

@implementation LocalNetworkChecker_Tests

- (void)testIPv4
{
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"0.0.0.3"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"10.10.10.10"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"127.0.0.1"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"192.168.123.123"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"192.168.254.254"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"240.0.0.0"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"255.255.255.255"]);
	
	XCTAssertFalse([LocalNetworkChecker isHostOnLocalNet:@"8.8.8.8"]);
	XCTAssertFalse([LocalNetworkChecker isHostOnLocalNet:@"123.123.123.123"]);
	XCTAssertFalse([LocalNetworkChecker isHostOnLocalNet:@"192.169.0.1"]);

	XCTAssertFalse([LocalNetworkChecker isHostOnLocalNet:@"-127.0.0.1"]);
	XCTAssertFalse([LocalNetworkChecker isHostOnLocalNet:@"not an ip"]);
}

- (void)testIPv6
{
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"::"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"::1"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"2001:10::1"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"::fFfF:192.168.1.1"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"::ffff:127.0.0.1"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"fe80::c34:c7f7:1003:300c%en0"]);
	XCTAssertTrue([LocalNetworkChecker isHostOnLocalNet:@"fdf9:39fa:41d9::1"]);

	XCTAssertFalse([LocalNetworkChecker isHostOnLocalNet:@"::abad:bad:1dea"]);
	XCTAssertFalse([LocalNetworkChecker isHostOnLocalNet:@"abad:bad:1dea::"]);
	XCTAssertFalse([LocalNetworkChecker isHostOnLocalNet:@"2620:0:1cfe:face:b00c::"]);
}

@end
