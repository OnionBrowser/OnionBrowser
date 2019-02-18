#import <XCTest/XCTest.h>
#import "HostSettings.h"

@interface HostSettings_Tests : XCTestCase
@end

@implementation HostSettings_Tests

- (void)setUp
{
	[super setUp];
	
	[HostSettings overrideHosts:[[NSMutableDictionary alloc] init]];
	
	HostSettings *hs = [[HostSettings alloc] initForHost:HOST_SETTINGS_DEFAULT withDict:nil];
	[hs save];
}

- (void)testJavascriptDefault
{
	HostSettings *hs = [HostSettings defaultHostSettings];
	[hs setSetting:HOST_SETTINGS_KEY_CSP toValue:HOST_SETTINGS_CSP_STRICT];
	[hs save];
	
	/* not present, should use defaults */
	HostSettings *blhs = [HostSettings settingsOrDefaultsForHost:@"browserleaks.com"];
	NSString *c = [blhs settingOrDefault:HOST_SETTINGS_KEY_CSP];
	XCTAssertTrue([c isEqualToString:HOST_SETTINGS_CSP_STRICT]);
	
	/* present but not changed, should still use defaults */
	HostSettings *blhs2 = [[HostSettings alloc] initForHost:@"browserleaks.com" withDict:nil];
	[blhs2 save];
	
	HostSettings *blhs3 = [HostSettings settingsOrDefaultsForHost:@"browserleaks.com"];
	NSString *c2 = [blhs3 settingOrDefault:HOST_SETTINGS_KEY_CSP];
	XCTAssertTrue([c2 isEqualToString:HOST_SETTINGS_CSP_STRICT]);
}

@end
