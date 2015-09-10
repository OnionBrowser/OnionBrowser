#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "CookieJar.h"
#import "HostSettings.h"

#define TRACE_COOKIES

@interface CookieJar_Tests : XCTestCase
@end

@implementation CookieJar_Tests

id HSMocked;
CookieJar *cookieJar;

- (void)setUp {
	[super setUp];
	// Put setup code here. This method is called before the invocation of each test method in the class.
	
	cookieJar = [[CookieJar alloc] init];
	
	HSMocked = OCMClassMock([HostSettings class]);
	OCMStub([HostSettings persist]).andDo(nil);

	[HostSettings overrideHosts:[[NSMutableDictionary alloc] init]];
	HostSettings *hs = [[HostSettings alloc] initForHost:@"reddit.com" withDict:@{ HOST_SETTINGS_KEY_WHITELIST_COOKIES: HOST_SETTINGS_VALUE_YES }];
	[hs save];
}

- (void)tearDown {
	// Put teardown code here. This method is called after the invocation of each test method in the class.
	[super tearDown];
}

- (void)testIsHostWhitelisted {
	XCTAssertTrue([cookieJar isHostWhitelisted:@"reddit.com"]);
	XCTAssertTrue([cookieJar isHostWhitelisted:@"assets.reddit.com"]);
	
	XCTAssertFalse([cookieJar isHostWhitelisted:@"reddit.com.com"]);
}

@end
