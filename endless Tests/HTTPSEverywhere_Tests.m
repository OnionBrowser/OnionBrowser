#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "HTTPSEverywhere.h"

#define TRACE_HTTPS_EVERYWHERE

@interface HTTPSEverywhere_Tests : XCTestCase
@end

@implementation HTTPSEverywhere_Tests

id HEMocked;

- (void)setUp {
	[super setUp];
	// Put setup code here. This method is called before the invocation of each test method in the class.
	
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
}

- (void)tearDown {
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)testMock {
	XCTAssertNotNil([[HTTPSEverywhere rules] objectForKey:@"Reddit"]);
	XCTAssertNotNil([[HTTPSEverywhere rules] objectForKey:@"Better Business Bureau (partial)"]);
	// make sure the big list didn't get loaded
	XCTAssertNil([[HTTPSEverywhere rules] objectForKey:@"EFF"]);
}

- (void)testApplicableRules {
	NSArray *results = [HTTPSEverywhere potentiallyApplicableRulesForHost:@"www.reddit.com"];
	XCTAssertEqual([results count], 1U);
	XCTAssert([[results objectAtIndex:0] isKindOfClass:[HTTPSEverywhereRule class]]);
	XCTAssert([[(HTTPSEverywhereRule *)[results objectAtIndex:0] name] isEqualToString:@"Reddit"]);
}

- (void)testRewrittenURI {
	NSURL *rewritten = [HTTPSEverywhere rewrittenURI:[NSURL URLWithString:@"http://www.reddit.com/test"] withRules:nil];
	XCTAssert([[rewritten absoluteString] isEqualToString:@"https://www.reddit.com/test"]);
	
	/* a more complex rewrite */
	rewritten = [HTTPSEverywhere rewrittenURI:[NSURL URLWithString:@"http://bbbonline.org/cks.asp?id=1234"] withRules:nil];
	XCTAssert([[rewritten absoluteString] isEqualToString:@"https://www.bbb.org/us/bbb-online-business/?id=1234"]);
}

- (void)testRewrittenURIWithExclusion {
	NSString *input = @"http://www.dc.bbb.org/";
	NSURL *rewritten = [HTTPSEverywhere rewrittenURI:[NSURL URLWithString:input] withRules:nil];
	XCTAssert([[rewritten absoluteString] isEqualToString:input]);
}

@end
