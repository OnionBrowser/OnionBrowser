#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "SSLCertificate.h"
#import "DTBase64Coding.h"

@interface SSLCertificate_Tests : XCTestCase
@end

@implementation SSLCertificate_Tests

- (NSData *)certDataFromFile:(NSString *)file
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:file ofType:@"crt"];

	XCTAssertTrue([fm fileExistsAtPath:path], @"%@.crt does not exist in resources", file);
	
	NSError *error;
	NSMutableString *strd = [[NSMutableString alloc] initWithString:[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error]];
	XCTAssertNil(error);
	
	[strd replaceOccurrencesOfString:@"-----BEGIN CERTIFICATE-----" withString:@"" options:0 range:NSMakeRange(0, [strd length])];
	[strd replaceOccurrencesOfString:@"-----END CERTIFICATE-----" withString:@"" options:0 range:NSMakeRange(0, [strd length])];
	return [DTBase64Coding dataByDecodingString:strd];
}

- (void)testBasicData
{
	SSLCertificate *c = [[SSLCertificate alloc] initWithData:[self certDataFromFile:@"lobste.rs"]];
	XCTAssertNotNil(c);
	XCTAssertEqualObjects([c version], @3);
	XCTAssertEqualObjects([c serialNumber], @"00:db:47:f4:4f:cc:8d:a5:eb:12:8e:af:08:aa:75:e9:11");
}

- (void)testSerialAsNumber
{
	SSLCertificate *c = [[SSLCertificate alloc] initWithData:[self certDataFromFile:@"wildcard.pushover.net"]];
	XCTAssertNotNil(c);
	XCTAssertEqualObjects([c serialNumber], @"aa:c1");
}

- (void)testEV
{
	SSLCertificate *c = [[SSLCertificate alloc] initWithData:[self certDataFromFile:@"paypal.com"]];
	XCTAssertNotNil(c);
	XCTAssertEqualObjects([c serialNumber], @"07:64:f7:ba:2d:02:17:1f:9c:48:0d:fe:7b:65:bb:6f");
	XCTAssertEqualObjects([[c subject] objectForKey:X509_KEY_CN], @"www.paypal.com");
}

- (void)testExpired
{
	SSLCertificate *c = [[SSLCertificate alloc] initWithData:[self certDataFromFile:@"expired.superblock.net"]];
	XCTAssertNotNil(c);
	XCTAssertEqualObjects([c serialNumber], @"00:85:1d:d2:53:35:1c:64:3b:f6:8e:23:ac:d2:e4:55:dd");
	XCTAssertTrue([c isExpired]);
}

@end
