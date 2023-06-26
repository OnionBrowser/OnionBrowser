#import <XCTest/XCTest.h>
#import "OnionBrowser-Swift.h"

@interface HostSettings_Tests : XCTestCase
@end

@implementation HostSettings_Tests

- (void)setUp
{
	[super setUp];

	HostSettings *hs = [HostSettings forDefault]; // Default host.
	[hs save];
}

- (void)testJavascriptDefault
{
	HostSettings *hs = [HostSettings forDefault];
	hs.javaScript = NO;
	[hs save];
	
	/* not present, should use defaults */
	HostSettings *blhs = [HostSettings for:@"browserleaks.com"];
	XCTAssertEqual(blhs.javaScript, NO);

	/* present but not changed, should still use defaults */
	HostSettings *blhs2 = [[HostSettings alloc] initFor:@"browserleaks.com" withDefaults:NO];
	[blhs2 save];
	
	HostSettings *blhs3 = [HostSettings for:@"browserleaks.com"];
	XCTAssertEqual(blhs3.javaScript, NO);
}

@end
