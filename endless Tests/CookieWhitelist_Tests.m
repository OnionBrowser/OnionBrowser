#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "CookieWhitelist.h"

#define TRACE_COOKIE_WHITELIST

@interface CookieWhitelist_Tests : XCTestCase
@end

@implementation CookieWhitelist_Tests

CookieWhitelist *whitelist;

- (void)setUp {
	[super setUp];
	// Put setup code here. This method is called before the invocation of each test method in the class.
	
	whitelist = [[CookieWhitelist alloc] init];
	[whitelist updateHostsWithArray:@[ @"reddit.com" ]];
}

- (void)tearDown {
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)testIsHostWhitelisted {
	XCTAssertTrue([whitelist isHostWhitelisted:@"reddit.com"]);
	XCTAssertTrue([whitelist isHostWhitelisted:@"assets.reddit.com"]);
	
	XCTAssertFalse([whitelist isHostWhitelisted:@"reddit.com.com"]);
}

@end
