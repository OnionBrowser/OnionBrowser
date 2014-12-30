#import <Foundation/Foundation.h>

#include <arpa/inet.h>

@implementation NSString (IPAddress)

- (BOOL)isValidIPAddress
{
	struct in_addr dst;
	int success;
	const char *utf8 = [self UTF8String];

	success = inet_pton(AF_INET, utf8, &dst);
	if (success != 1) {
		struct in6_addr dst6;
		success = inet_pton(AF_INET6, utf8, &dst6);
	}
	
	return (success == 1);
}

@end
