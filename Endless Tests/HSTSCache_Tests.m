#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "OnionBrowser-Swift.h"

#define TRACE_HSTS

#define HSTS_KEY_ALLOW_SUBDOMAINS @"allowSubdomains"
#define HSTS_KEY_EXPIRATION @"expiration"

@interface HSTSCache_Tests : XCTestCase
@end

@implementation HSTSCache_Tests {
	HstsCache *hstsCache;
}

- (void)setUp
{
	[super setUp];
	
	hstsCache =  HstsCache.shared;
}

- (void)testParseHSTSHeader
{
	[hstsCache parseHstsHeader:@"max-age=12345; includeSubDomains" for:@"example.com"];

	NSDictionary *params = [hstsCache _testingOnlyEntry:@"example.com"];
	XCTAssertNotNil(params);
	XCTAssertNotNil([params objectForKey:HSTS_KEY_ALLOW_SUBDOMAINS]);
	XCTAssertNotNil([params objectForKey:HSTS_KEY_EXPIRATION]);
	
	XCTAssertTrue([(NSDate *)[params objectForKey:HSTS_KEY_EXPIRATION] timeIntervalSince1970] - [[NSDate date] timeIntervalSince1970] >= 12340);
}

- (void)testIgnoreIPAddresses
{
	[hstsCache parseHstsHeader:@"max-age=12345; includeSubDomains" for:@"127.0.0.1"];
	
	NSDictionary *params = [hstsCache _testingOnlyEntry:@"127.0.0.1"];
	XCTAssertNil(params);
}

- (void)testParseUpdatedHSTSHeader
{
	[hstsCache parseHstsHeader:@"max-age=12345; includeSubDomains" for:@"example.com"];
	
	NSDictionary *params = [hstsCache _testingOnlyEntry:@"example.com"];
	XCTAssertNotNil(params);
	XCTAssertNotNil([params objectForKey:HSTS_KEY_ALLOW_SUBDOMAINS]);
	
	/* now a new request presents without includeSubDomains */
	[hstsCache parseHstsHeader:@"max-age=12345" for:@"example.com"];
	
	params = [hstsCache _testingOnlyEntry:@"example.com"];
	XCTAssertNotNil(params);
	XCTAssertNil([params objectForKey:HSTS_KEY_ALLOW_SUBDOMAINS]);
}

- (void)testParseEFFHSTSHeader
{
	/* weirdo header that eff sends (to cover old spec?) */
	[hstsCache parseHstsHeader:@"max-age=31536000; includeSubdomains, max-age=31536000; includeSubdomains" for:@"www.EFF.org"];
	
	NSDictionary *params = [hstsCache _testingOnlyEntry:@"www.eff.org"];
	XCTAssertNotNil(params);
	XCTAssertNotNil([params objectForKey:HSTS_KEY_ALLOW_SUBDOMAINS]);
	XCTAssertNotNil([params objectForKey:HSTS_KEY_EXPIRATION]);
}

- (void)testURLRewriting
{
	[hstsCache parseHstsHeader:@"max-age=31536000; includeSubdomains, max-age=31536000; includeSubdomains" for:@"www.EFF.org"];
	
	NSURL *output = [hstsCache rewriteURL:[NSURL URLWithString:@"http://www.eff.org/test"]];
	XCTAssertTrue([[output absoluteString] isEqualToString:@"https://www.eff.org/test"]);
	
	/* we didn't see the header for "eff.org", so subdomains have to be of www */
	output = [hstsCache rewriteURL:[NSURL URLWithString:@"http://subdomain.eff.org/test"]];
	XCTAssertNotEqualObjects([output absoluteString], @"https://subdomain.eff.org/test");
	
	output = [hstsCache rewriteURL:[NSURL URLWithString:@"http://subdomain.www.eff.org/test"]];
	XCTAssertEqualObjects([output absoluteString], @"https://subdomain.www.eff.org/test");

	output = [hstsCache rewriteURL:[NSURL URLWithString:@"http://www.eff.org:1234/?what#hi"]];
	XCTAssertEqualObjects([output absoluteString], @"https://www.eff.org:1234/?what#hi");
	
	output = [hstsCache rewriteURL:[NSURL URLWithString:@"http://www.eff.org:80/?what#hi"]];
	XCTAssertEqualObjects([output absoluteString], @"https://www.eff.org/?what#hi");
}

- (void)testExpiring
{
	[hstsCache parseHstsHeader:@"max-age=2; includeSubDomains" for:@"example.com"];
	
	NSURL *output = [hstsCache rewriteURL:[NSURL URLWithString:@"http://www.example.com/"]];
	XCTAssertEqualObjects([output absoluteString], @"https://www.example.com/");
	
	NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:4];
	
	do {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeoutDate];
		if ([timeoutDate timeIntervalSinceNow] < 0)
			break;
	} while (TRUE);
	
	/* expired */
	output = [hstsCache rewriteURL:[NSURL URLWithString:@"http://www.example.com/"]];
	XCTAssertEqualObjects([output absoluteString], @"http://www.example.com/");
}

@end
