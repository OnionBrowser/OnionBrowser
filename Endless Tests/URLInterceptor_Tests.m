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
	NSString *outp = [URLInterceptor prependDirectivesIfExisting:@{
								       @"frame-src": @[ @"endless:", @"endless:" ],
								       @"child-src": @[ @"endless:", @"endless:" ]
								       } inCSPHeader:inp];
	XCTAssertEqualObjects(outp, @"connect-src 'self'; default-src 'self'; font-src 'self' data:; frame-ancestors https://*.twitter.com; frame-src endless: https://twitter.com https://*.twitter.com https://*.twimg.com twitter: https://www.google.com https://5415703.fls.doubleclick.net; img-src https://twitter.com https://*.twitter.com https://*.twimg.com https://maps.google.com https://www.google-analytics.com https://stats.g.doubleclick.net https://www.google.com https://ad.doubleclick.net data:; media-src https://*.twitter.com https://*.twimg.com https://*.cdn.vine.co; object-src 'self'; report-uri https://twitter.com/i/csp_report?a=O5SWEZTPOJQWY3A%3D&ro=false; script-src 'unsafe-inline' 'unsafe-eval' https://*.twitter.com https://*.twimg.com https://www.google.com https://www.google-analytics.com https://stats.g.doubleclick.net; style-src 'unsafe-inline' https://*.twitter.com https://*.twimg.com;");
}

- (void)testCSPHeaderNoneRemoval
{
	/* make sure 'none' is removed and our value is used */
	NSString *outp = [URLInterceptor prependDirectivesIfExisting:@{
								       @"frame-src": @[ @"endless:", @"endless:" ]
								       } inCSPHeader:@"blah-src 'self';frame-src 'none' ; blah2-src 'none';"];
	XCTAssertEqualObjects(outp, @"blah-src 'self'; blah2-src 'none'; frame-src endless:;");
}

- (void)testCSPHeaderSelectiveInclusion
{
	/* only change directives if they existed in the original policy */
	NSString *outp = [URLInterceptor prependDirectivesIfExisting:@{
								       @"child-src": @[ @"endlessipc:", @"endlessipc:" ],
								       @"frame-src": @[ @"endlessipc:", @"endlessipc:" ],
								       @"script-src" : @[ @"'none'", @"'none'" ]
								       } inCSPHeader:@"referrer always;"];
	XCTAssertEqualObjects(outp, @"referrer always;");
}

- (void)testCSPHeaderSelectiveNonce
{
	NSDictionary *wantedDirectives = @{
					   @"child-src": @[ @"endlessipc:", @"endlessipc:" ],
					   @"default-src" : @[ @"endlessipc:", @"'nonce-blah' endlessipc:" ],
					   @"frame-src": @[ @"endlessipc:", @"endlessipc:" ],
					   @"script-src" : @[ @"", @"'nonce-blah'" ],
					   };

	/* only prepend nonced values if the original directive contained '{sha256|sha384|sha512|nonce}-.*' */
	NSString *inp = @"default-src 'self'; script-src https://cdn.example.com 'sha512-abcdefghijkl'; style-src 'unsafe-inline'";
	NSString *outp = [URLInterceptor prependDirectivesIfExisting:wantedDirectives inCSPHeader:inp];
	XCTAssertEqualObjects(outp, @"default-src endlessipc: 'self'; script-src 'nonce-blah' https://cdn.example.com 'sha512-abcdefghijkl'; style-src 'unsafe-inline';");

	/* when it doesn't use nonces, use the non-nonced version */
	NSString *inp2 = @"default-src 'self'; connect-src https://localhost https://*.instapaper.com https://*.stripe.com https://getpocket.com https://m.signalvnoise.com https://*.m.signalvnoise.com https://*.medium.com https://medium.com https://*.medium.com https://*.algolia.net https://cdn-static-1.medium.com https://dnqgz544uhbo8.cloudfront.net https://*.lightstep.com 'self'; font-src data: https://*.amazonaws.com https://*.medium.com https://*.gstatic.com https://dnqgz544uhbo8.cloudfront.net https://use.typekit.net https://cdn-static-1.medium.com 'self'; frame-src chromenull: https: webviewprogressproxy: medium: 'self'; img-src blob: data: https: 'self'; media-src https://*.cdn.vine.co https://d1fcbxp97j4nb2.cloudfront.net https://d262ilb51hltx0.cloudfront.net https://medium2.global.ssl.fastly.net https://*.medium.com https://gomiro.medium.com https://miro.medium.com https://pbs.twimg.com 'self'; object-src 'self'; script-src 'unsafe-eval' 'unsafe-inline' about: https: 'self'; style-src 'unsafe-inline' data: https: 'self'; report-uri https://csp.medium.com";
	NSString *outp2 = [URLInterceptor prependDirectivesIfExisting:wantedDirectives inCSPHeader:inp2];
	XCTAssertEqualObjects(outp2, @"connect-src https://localhost https://*.instapaper.com https://*.stripe.com https://getpocket.com https://m.signalvnoise.com https://*.m.signalvnoise.com https://*.medium.com https://medium.com https://*.medium.com https://*.algolia.net https://cdn-static-1.medium.com https://dnqgz544uhbo8.cloudfront.net https://*.lightstep.com 'self'; default-src endlessipc: 'self'; font-src data: https://*.amazonaws.com https://*.medium.com https://*.gstatic.com https://dnqgz544uhbo8.cloudfront.net https://use.typekit.net https://cdn-static-1.medium.com 'self'; frame-src endlessipc: chromenull: https: webviewprogressproxy: medium: 'self'; img-src blob: data: https: 'self'; media-src https://*.cdn.vine.co https://d1fcbxp97j4nb2.cloudfront.net https://d262ilb51hltx0.cloudfront.net https://medium2.global.ssl.fastly.net https://*.medium.com https://gomiro.medium.com https://miro.medium.com https://pbs.twimg.com 'self'; object-src 'self'; report-uri https://csp.medium.com; script-src 'unsafe-eval' 'unsafe-inline' about: https: 'self'; style-src 'unsafe-inline' data: https: 'self';");
}

@end
