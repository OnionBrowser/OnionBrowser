/*
 * Onion Browser
 * Copyright (c) 2012-2018, Tigas Ventures, LLC (Mike Tigas)
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import "Ipv6Tester.h"
#include <sys/socket.h>
#include <netdb.h>
#import <ifaddrs.h>
#import <arpa/inet.h>
#include <err.h>
#include <net/if.h>

@implementation Ipv6Tester

+ (NSInteger) ipv6_status {
	Reachability* reach = [Reachability reachabilityForInternetConnection];

	if (reach.currentReachabilityStatus != NotReachable) {
		Boolean haveNonLocalIpv4 = NO;
		Boolean haveNonLocalIpv6 = NO;


		NSDictionary *ipv4addrs = [Ipv6Tester addressesForProtocol:4];
		for(NSString *iface in ipv4addrs) {
			NSString *addr = (NSString *)[ipv4addrs objectForKey:iface];
			//NSLog(@"%@: %@", iface, addr);
			if ([iface hasPrefix:@"en"] || [iface hasPrefix:@"pdp_ip"]) {
				// TODO better logic for non-public, non-valid IPv4 addresses
				if (![addr hasPrefix:@"127."] && ![addr hasPrefix:@"0."] && ![addr hasPrefix:@"169.254."] && ![addr hasPrefix:@"255."]) {
					haveNonLocalIpv4 = YES;
					//NSLog(@"OK");
					break;
				}
			}
		}

		NSDictionary *ipv6addrs = [Ipv6Tester addressesForProtocol:6];
		for(NSString *iface in ipv6addrs) {
			NSString *addr = (NSString *)[ipv6addrs objectForKey:iface];
			//NSLog(@"%@: %@", iface, addr);
			if ([iface hasPrefix:@"en"] || [iface hasPrefix:@"pdp_ip"]) {
				// TODO better logic for non-public, non-valid IPv6 addresses
				if (![addr hasPrefix:@"fe80:"]) {
					haveNonLocalIpv6 = YES;
					//NSLog(@"OK");
					break;
				}
			}
		}
		if (haveNonLocalIpv4 && haveNonLocalIpv6) {
			return TOR_IPV6_CONN_DUAL;
		} else if (!haveNonLocalIpv4 && haveNonLocalIpv6) {
			return TOR_IPV6_CONN_ONLY;
		} else {
			return TOR_IPV6_CONN_FALSE;
		}
	} else {
		return TOR_IPV6_CONN_UNKNOWN;
	}
}


/* Per apple docs:
   If your app needs to connect to an IPv4-only server without a DNS hostname,
   use getaddrinfo to resolve the IPv4 address literal. If the current network
   interface doesn’t support IPv4, but supports IPv6, NAT64, and DNS64,
   performing this task will result in a synthesized IPv6 address.
*/
/*
+ (void) test_dns_6 {
	uint8_t ipv4[4] = {192, 0, 2, 1};
	struct addrinfo hints, *res, *res0;
	int error, s;
	//const char *cause = NULL;

	char ipv4_str_buf[INET_ADDRSTRLEN] = { 0 };
	const char *ipv4_str = inet_ntop(AF_INET, &ipv4, ipv4_str_buf, sizeof(ipv4_str_buf));

	memset(&hints, 0, sizeof(hints));
	hints.ai_family = PF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_flags = AI_DEFAULT;
	error = getaddrinfo(ipv4_str, "http", &hints, &res0);
	if (error) {
		errx(1, "%s", gai_strerror(error));
	}
	s = -1;
	for (res = res0; res; res = res->ai_next) {
		NSLog(@"fam %d", res->ai_family);
		NSLog(@"proto %d", res->ai_protocol);
		NSLog(@"socktype %d", res->ai_socktype);
		NSLog(@"addrlen %d", res->ai_addrlen);
		NSLog(@"addr %@", [NSString stringWithCString:res->ai_addr->sa_data encoding:NSUTF8StringEncoding]);
		//s = socket(res->ai_family, res->ai_socktype,
		//		   res->ai_protocol);
		//if (s < 0) {
		//	cause = "socket";
		//	continue;
		//}
		//if (connect(s, res->ai_addr, res->ai_addrlen) < 0) {
		//	cause = "connect";
		//	close(s);
		//	s = -1;
		//	continue;
		//}
		//break;
	}
	//if (s < 0) {
	//	err(1, "%s", cause);
	//}
	freeaddrinfo(res0);
}
*/
+(NSDictionary *)addressesForProtocol:(int)ipVersion
{
	NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];

	// retrieve the current interfaces - returns 0 on success
	struct ifaddrs *interfaces;
	if(!getifaddrs(&interfaces)) {
		// Loop through linked list of interfaces
		struct ifaddrs *interface;
		for(interface=interfaces; interface; interface=interface->ifa_next) {
			if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
				continue; // deeply nested code harder to read
			}
			const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
			char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
			if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
				NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
				NSInteger type = 0;
				if(addr->sin_family == AF_INET) {
					if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
						type = 4;
					}
				} else {
					const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
					if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
						type = 6;
					}
				}
				if(type == ipVersion) {
					NSString *key = [NSString stringWithFormat:@"%@/%ld", name, (long)type];
					addresses[key] = [NSString stringWithUTF8String:addrBuf];
				}
			}
		}
		// Free memory
		freeifaddrs(interfaces);
	}
	return [addresses count] ? addresses : nil;
}

@end
