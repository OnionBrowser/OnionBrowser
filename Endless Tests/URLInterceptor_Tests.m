//
//  URLInterceptor_Tests.m
//  Endless
//
//  Created by joshua stein on 12/20/16.
//  Copyright © 2016 jcs. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "URLInterceptor.h"

@interface URLInterceptor_Tests : XCTestCase

@end

@implementation URLInterceptor_Tests

- (void)testCSPHeaderInjection
{
	NSString *inp = @"default-src 'self'; connect-src 'self'; font-src 'self' data:; frame-src https://twitter.com https://*.twitter.com https://*.twimg.com twitter: https://www.google.com https://5415703.fls.doubleclick.net; frame-ancestors https://*.twitter.com; img-src https://twitter.com https://*.twitter.com https://*.twimg.com https://maps.google.com https://www.google-analytics.com https://stats.g.doubleclick.net https://www.google.com https://ad.doubleclick.net data:; media-src https://*.twitter.com https://*.twimg.com https://*.cdn.vine.co; object-src 'self'; script-src 'unsafe-inline' 'unsafe-eval' https://*.twitter.com https://*.twimg.com https://www.google.com https://www.google-analytics.com https://stats.g.doubleclick.net; style-src 'unsafe-inline' https://*.twitter.com https://*.twimg.com; report-uri https://twitter.com/i/csp_report?a=O5SWEZTPOJQWY3A%3D&ro=false;";
	
	NSString *outp = [URLInterceptor prependDirectivesIfExisting:@{ @"frame-src": @"endless:", @"child-src": @"endless:"} inCSPHeader:inp];
	
	XCTAssertEqualObjects(outp, @"connect-src 'self'; default-src 'self'; font-src 'self' data:; frame-ancestors https://*.twitter.com; frame-src endless: https://twitter.com https://*.twitter.com https://*.twimg.com twitter: https://www.google.com https://5415703.fls.doubleclick.net; img-src https://twitter.com https://*.twitter.com https://*.twimg.com https://maps.google.com https://www.google-analytics.com https://stats.g.doubleclick.net https://www.google.com https://ad.doubleclick.net data:; media-src https://*.twitter.com https://*.twimg.com https://*.cdn.vine.co; object-src 'self'; report-uri https://twitter.com/i/csp_report?a=O5SWEZTPOJQWY3A%3D&ro=false; script-src 'unsafe-inline' 'unsafe-eval' https://*.twitter.com https://*.twimg.com https://www.google.com https://www.google-analytics.com https://stats.g.doubleclick.net; style-src 'unsafe-inline' https://*.twitter.com https://*.twimg.com;");
}

- (void)testCSPHeaderNoneRemoval
{
	/* make sure 'none' is removed and our value is used */
	NSString *outp = [URLInterceptor prependDirectivesIfExisting:@{ @"frame-src": @"endless:" } inCSPHeader:@"blah-src 'self';frame-src 'none' ; blah2-src 'none';"];
	XCTAssertEqualObjects(outp, @"blah-src 'self'; blah2-src 'none'; frame-src endless:;");
}

- (void)testCSPHeaderSelectiveInclusion
{
	/* only change directives if they existed in the original policy */
	NSString *outp = [URLInterceptor prependDirectivesIfExisting:@{ @"child-src": @"endlessipc:", @"frame-src": @"endlessipc:", @"script-src" : @"'none'" } inCSPHeader:@"referrer always;"];
	XCTAssertEqualObjects(outp, @"referrer always;");
}

@end
