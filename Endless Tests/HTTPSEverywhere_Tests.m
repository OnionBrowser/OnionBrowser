#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "HTTPSEverywhere.h"

#define TRACE_HTTPS_EVERYWHERE

@interface HTTPSEverywhere_Tests : XCTestCase
@end

@implementation HTTPSEverywhere_Tests {
	id HEMocked;
}

- (void)setUp
{
	[super setUp];
	
	HEMocked = OCMClassMock([HTTPSEverywhere class]);
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"https-everywhere_mock_rules" ofType:@"plist"];
	if (![fm fileExistsAtPath:path])
		abort();
	
	OCMStub([HEMocked rules]).andReturn([NSDictionary dictionaryWithContentsOfFile:path]);
	
	NSString *tpath = [[NSBundle bundleForClass:[self class]] pathForResource:@"https-everywhere_mock_targets" ofType:@"plist"];
	if (![fm fileExistsAtPath:tpath])
		abort();

	OCMStub([HEMocked targets]).andReturn([NSDictionary dictionaryWithContentsOfFile:tpath]);
	
	OCMStub([HEMocked disabledRules]).andReturn([[NSMutableDictionary alloc] init]);
}

- (void)testMock
{
	XCTAssertNotNil([[HTTPSEverywhere rules] objectForKey:@"Reddit"]);
	XCTAssertNotNil([[HTTPSEverywhere rules] objectForKey:@"Better Business Bureau (partial)"]);
	// make sure the big list didn't get loaded
	XCTAssertNil([[HTTPSEverywhere rules] objectForKey:@"EFF"]);
}

- (void)testApplicableRules
{
	NSArray *results = [HTTPSEverywhere potentiallyApplicableRulesForHost:@"www.reddit.com"];
	XCTAssertEqual([results count], 1U);
	XCTAssert([[results objectAtIndex:0] isKindOfClass:[HTTPSEverywhereRule class]]);
	XCTAssertEqualObjects([(HTTPSEverywhereRule *)[results objectAtIndex:0] name], @"Reddit");
}

- (void)testRewrittenURI
{
	NSURL *rewritten = [HTTPSEverywhere rewrittenURI:[NSURL URLWithString:@"http://www.reddit.com/test"] withRules:nil];
	XCTAssertEqualObjects([rewritten absoluteString], @"https://www.reddit.com/test");
	
	/* a more complex rewrite */
	rewritten = [HTTPSEverywhere rewrittenURI:[NSURL URLWithString:@"http://bbbonline.org/cks.asp?id=1234"] withRules:nil];
	XCTAssertEqualObjects([rewritten absoluteString], @"https://www.bbb.org/us/bbb-online-business/?id=1234");
}

- (void)testRewrittenURIWithExclusion
{
	NSString *input = @"http://www.dc.bbb.org/";
	NSURL *rewritten = [HTTPSEverywhere rewrittenURI:[NSURL URLWithString:input] withRules:nil];
	XCTAssert([[rewritten absoluteString] isEqualToString:input]);
	
	input = @"http://www.partnerinfo.lenovo.com/blah";
	rewritten = [HTTPSEverywhere rewrittenURI:[NSURL URLWithString:input] withRules:nil];
	XCTAssertEqualObjects([rewritten absoluteString], input);
}

- (void)testRewrittenURIDowngradedWithCapture
{
	NSString *input = @"https://www.partnerinfo.lenovo.com/blah";
	NSString *output = @"http://www.partnerinfo.lenovo.com/blah";

	NSURL *rewritten = [HTTPSEverywhere rewrittenURI:[NSURL URLWithString:input] withRules:nil];
	XCTAssertEqualObjects([rewritten absoluteString], output);
}

- (void)testWildcardInApplicableRules
{
	NSArray *results = [HTTPSEverywhere potentiallyApplicableRulesForHost:@"www.lenovo.com"];
	XCTAssertEqual([results count], 1U);
	
	results = [HTTPSEverywhere potentiallyApplicableRulesForHost:@"youropinioncounts.lenovo.com"];
	XCTAssertEqual([results count], 0);
}

@end
