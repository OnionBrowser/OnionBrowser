#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>

#import "CookieJar.h"
#import "HostSettings.h"

#define TRACE_COOKIES

@interface CookieJar_Tests : XCTestCase
@end

@implementation CookieJar_Tests {
	CookieJar *cookieJar;
}

- (void)setUp
{
	[super setUp];

	cookieJar = [[CookieJar alloc] init];

	[HostSettings overrideHosts:[[NSMutableDictionary alloc] init]];
	HostSettings *hs = [[HostSettings alloc] initForHost:@"reddit.com" withDict:@{ HOST_SETTINGS_KEY_WHITELIST_COOKIES: HOST_SETTINGS_VALUE_YES }];
	[hs save];
}

- (void)testIsHostWhitelisted
{
	XCTAssertTrue([cookieJar isHostWhitelisted:@"reddit.com"]);
	XCTAssertTrue([cookieJar isHostWhitelisted:@"assets.reddit.com"]);
	
	XCTAssertFalse([cookieJar isHostWhitelisted:@"reddit.com.com"]);
}

@end
