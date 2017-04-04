#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "HSTSCache.h"

#define TRACE_HSTS

@interface HSTSCache_Tests : XCTestCase
@end

@implementation HSTSCache_Tests {
	HSTSCache *hstsCache;
}

- (void)setUp
{
	[super setUp];
	
	hstsCache = [[HSTSCache alloc] init];
}

- (void)testParseHSTSHeader
{
	[hstsCache parseHSTSHeader:@"max-age=12345; includeSubDomains" forHost:@"example.com"];
	
	NSDictionary *params = [hstsCache objectForKey:@"example.com"];
	XCTAssertNotNil(params);
	XCTAssertNotNil([params objectForKey:HSTS_KEY_ALLOW_SUBDOMAINS]);
	XCTAssertNotNil([params objectForKey:HSTS_KEY_EXPIRATION]);
	
	XCTAssertTrue([(NSDate *)[params objectForKey:HSTS_KEY_EXPIRATION] timeIntervalSince1970] - [[NSDate date] timeIntervalSince1970] >= 12340);
}

- (void)testIgnoreIPAddresses
{
	[hstsCache parseHSTSHeader:@"max-age=12345; includeSubDomains" forHost:@"127.0.0.1"];
	
	NSDictionary *params = [hstsCache objectForKey:@"127.0.0.1"];
	XCTAssertNil(params);
}

- (void)testParseUpdatedHSTSHeader
{
	[hstsCache parseHSTSHeader:@"max-age=12345; includeSubDomains" forHost:@"example.com"];
	
	NSDictionary *params = [hstsCache objectForKey:@"example.com"];
	XCTAssertNotNil(params);
	XCTAssertNotNil([params objectForKey:HSTS_KEY_ALLOW_SUBDOMAINS]);
	
	/* now a new request presents without includeSubDomains */
	[hstsCache parseHSTSHeader:@"max-age=12345" forHost:@"example.com"];
	
	params = [hstsCache objectForKey:@"example.com"];
	XCTAssertNotNil(params);
	XCTAssertNil([params objectForKey:HSTS_KEY_ALLOW_SUBDOMAINS]);
}

- (void)testParseEFFHSTSHeader
{
	/* weirdo header that eff sends (to cover old spec?) */
	[hstsCache parseHSTSHeader:@"max-age=31536000; includeSubdomains, max-age=31536000; includeSubdomains" forHost:@"www.EFF.org"];
	
	NSDictionary *params = [hstsCache objectForKey:@"www.eff.org"];
	XCTAssertNotNil(params);
	XCTAssertNotNil([params objectForKey:HSTS_KEY_ALLOW_SUBDOMAINS]);
	XCTAssertNotNil([params objectForKey:HSTS_KEY_EXPIRATION]);
}

- (void)testURLRewriting
{
	[hstsCache parseHSTSHeader:@"max-age=31536000; includeSubdomains, max-age=31536000; includeSubdomains" forHost:@"www.EFF.org"];
	
	NSURL *output = [hstsCache rewrittenURI:[NSURL URLWithString:@"http://www.eff.org/test"]];
	XCTAssertTrue([[output absoluteString] isEqualToString:@"https://www.eff.org/test"]);
	
	/* we didn't see the header for "eff.org", so subdomains have to be of www */
	output = [hstsCache rewrittenURI:[NSURL URLWithString:@"http://subdomain.eff.org/test"]];
	XCTAssertNotEqualObjects([output absoluteString], @"https://subdomain.eff.org/test");
	
	output = [hstsCache rewrittenURI:[NSURL URLWithString:@"http://subdomain.www.eff.org/test"]];
	XCTAssertEqualObjects([output absoluteString], @"https://subdomain.www.eff.org/test");

	output = [hstsCache rewrittenURI:[NSURL URLWithString:@"http://www.eff.org:1234/?what#hi"]];
	XCTAssertEqualObjects([output absoluteString], @"https://www.eff.org:1234/?what#hi");
	
	output = [hstsCache rewrittenURI:[NSURL URLWithString:@"http://www.eff.org:80/?what#hi"]];
	XCTAssertEqualObjects([output absoluteString], @"https://www.eff.org/?what#hi");
}

- (void)testExpiring
{
	[hstsCache parseHSTSHeader:@"max-age=2; includeSubDomains" forHost:@"example.com"];
	
	NSURL *output = [hstsCache rewrittenURI:[NSURL URLWithString:@"http://www.example.com/"]];
	XCTAssertEqualObjects([output absoluteString], @"https://www.example.com/");
	
	NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:4];
	
	do {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeoutDate];
		if ([timeoutDate timeIntervalSinceNow] < 0)
			break;
	} while (TRUE);
	
	/* expired */
	output = [hstsCache rewrittenURI:[NSURL URLWithString:@"http://www.example.com/"]];
	XCTAssertEqualObjects([output absoluteString], @"http://www.example.com/");
}

@end
