#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "URLBlocker.h"

#define TRACE_URL_BLOCKER

@interface URLBlocker_Tests : XCTestCase
@end

@implementation URLBlocker_Tests {
	id HEMocked;
}

- (void)setUp {
	[super setUp];
	// Put setup code here. This method is called before the invocation of each test method in the class.
	
	HEMocked = OCMClassMock([URLBlocker class]);
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *tpath = [[NSBundle bundleForClass:[self class]] pathForResource:@"urlblocker_mock_targets" ofType:@"plist"];
	if (![fm fileExistsAtPath:tpath])
		abort();
	
	OCMStub([URLBlocker targets]).andReturn([NSDictionary dictionaryWithContentsOfFile:tpath]);
}

- (void)tearDown {
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)testShouldBlockURL {
	BOOL block = [URLBlocker shouldBlockURL:[NSURL URLWithString:@"https://twitter.com/"]];
	XCTAssert(block == YES);

	BOOL block2 = [URLBlocker shouldBlockURL:[NSURL URLWithString:@"https://platform.twitter.com/widgets.js"]];
	XCTAssert(block2 == YES);
	
	BOOL block3 = [URLBlocker shouldBlockURL:[NSURL URLWithString:@"https://platform.twitter-com/widgets.js"]];
	XCTAssert(block3 == NO);
}

- (void)testNotBlockingFromSameSite {
	BOOL block = [URLBlocker shouldBlockURL:[NSURL URLWithString:@"https://twitter.com/"] fromMainDocumentURL:[NSURL URLWithString:@"https://www.twitter.com/"]];
	XCTAssert(block == NO);

	BOOL block2 = [URLBlocker shouldBlockURL:[NSURL URLWithString:@"https://platform.twitter.com/widgets.js"] fromMainDocumentURL:[NSURL URLWithString:@"https://twitter.com/jcs/status/548344727771545600"]];
	XCTAssert(block2 == NO);

	BOOL block3 = [URLBlocker shouldBlockURL:[NSURL URLWithString:@"https://platform.twitter.com/widgets.js"] fromMainDocumentURL:[NSURL URLWithString:@"https://jcs.org/statuses/2014/12/25/548344727771545600/"]];
	XCTAssert(block3 == YES);
}

@end
