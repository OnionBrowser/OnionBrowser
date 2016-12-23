/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "LocalNetworkChecker.h"

#import <netinet/in.h>
#import <netdb.h>
#import <ifaddrs.h>
#import <arpa/inet.h>

@implementation LocalNetworkChecker

static NSArray *localNets;
static NSArray *local6Nets;
static NSMutableDictionary *dnsCache;

+ (void)clearCache
{
	if (dnsCache) {
		[dnsCache removeAllObjects];
	}
	else {
		dnsCache = [[NSMutableDictionary alloc] initWithCapacity:20];
	}
}

/* iOS has its internal DNS cache, so this does not have to send out another request on the wire */
+ (NSArray *)addressesForHostname:(NSString *)host {
	if (!dnsCache) {
		[[self class] clearCache];
	}
	
	id cached = [dnsCache objectForKey:[host lowercaseString]];
	if (cached != nil) {
		NSDictionary *dcache = (NSDictionary *)cached;
		NSDate *t = [dcache objectForKey:@"time"];
		if ([[NSDate date] timeIntervalSinceDate:t] < 30) {
			return [dcache objectForKey:@"addresses"];
		}
	}
	
	CFHostRef hostRef = CFHostCreateWithName(kCFAllocatorDefault, (__bridge CFStringRef)host);
	if (!CFHostStartInfoResolution(hostRef, kCFHostAddresses, nil)) {
		CFRelease(hostRef);
		return nil;
	}

	CFArrayRef addressesRef = CFHostGetAddressing(hostRef, nil);
	if (addressesRef == nil) {
		CFRelease(hostRef);
		return nil;
	}
	
	char ipAddress[INET6_ADDRSTRLEN];
	NSMutableArray *addresses = [NSMutableArray array];
	CFIndex numAddresses = CFArrayGetCount(addressesRef);
	for (CFIndex currentIndex = 0; currentIndex < numAddresses; currentIndex++) {
		struct sockaddr *address = (struct sockaddr *)CFDataGetBytePtr(CFArrayGetValueAtIndex(addressesRef, currentIndex));
		if (address == nil) {
			CFRelease(hostRef);
			return nil;
		}
		
		if (getnameinfo(address, address->sa_len, ipAddress, INET6_ADDRSTRLEN, nil, 0, NI_NUMERICHOST) != 0) {
			CFRelease(hostRef);
			return nil;
		}
		
		[addresses addObject:[NSString stringWithCString:ipAddress encoding:NSASCIIStringEncoding]];
	}
	CFRelease(hostRef);

	[dnsCache setValue:@{ @"addresses" : addresses, @"time" : [NSDate date] } forKey:[host lowercaseString]];
	
	return addresses;
}

+ (BOOL)isHostOnLocalNet:(NSString *)host
{
	if (!localNets) {
		NSMutableArray *tLocalNets = [[NSMutableArray alloc] init];
		[@{
			/* rfc6890 */
			@"0.0.0.0" : @8,
			@"10.0.0.0" : @8,
			@"100.64.0.0" : @10,
			@"127.0.0.0" : @8,
			@"169.254.0.0" : @16,
			@"172.16.0.0" : @12,
			@"192.0.0.0" : @24,
			@"192.0.2.0" : @24,
			@"192.88.99.0" : @24,
			@"192.168.0.0" : @16,
			@"198.18.0.0" : @15,
			@"198.51.100.0" : @24,
			@"203.0.113.0" : @24,
			@"224.0.0.0" : @4,
			@"240.0.0.0" : @4,
		} enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
			struct in_addr addr;

			if (inet_aton([key UTF8String], &addr) != 0) {
				uint32_t ip = ntohl(addr.s_addr);
				int cidr = [(NSNumber *)value intValue];
				uint32_t last = ip + (uint32_t)pow(2, (32 - cidr)) - 1;
				
				[tLocalNets addObject:@[ [NSNumber numberWithLongLong:ip], [NSNumber numberWithLongLong:last], key, value ]];
			} else {
				NSLog(@"[LocalNetworkChecker] failed parsing IP %@", key);
				abort();
			}
		}];
		
		localNets = [NSArray arrayWithArray:tLocalNets];
	}
	
	if (!local6Nets) {
		NSMutableArray *tLocal6Nets = [[NSMutableArray alloc] init];
		[@{
			/* https://en.wikipedia.org/wiki/Martian_packet#IPv6 */
			@"::" : @96,
			@"::1" : @128,
			@"::ffff:0:0" : @96,
			@"100::" : @64,
			@"2001:10::" : @28,
			@"2001:db8::" : @32,
			@"fc00::" : @7,
			@"fe80::" : @10,
			@"fec0::" : @10,
			@"ff00::" : @8,
			@"2001::" : @40,
			@"2001:0:7f00::" : @40,
			@"2001:0:a00::" : @40,
			@"2001:0:a9fe::" : @48,
			@"2001:0:ac10::" : @44,
			@"2001:0:c000:200::" : @56,
			@"2001:0:c000::" : @56,
			@"2001:0:c0a8::" : @48,
			@"2001:0:c612::" : @47,
			@"2001:0:c633:6400::" : @56,
			@"2001:0:cb00:7100::" : @56,
			@"2001:0:e000::" : @36,
			@"2001:0:f000::" : @36,
			@"2001:0:ffff:ffff::" : @64,
			@"2002::" : @24,
			@"2002:7f00::" : @24,
			@"2002:a00::" : @24,
			@"2002:a9fe::" : @32,
			@"2002:ac10::" : @28,
			@"2002:c000:200::" : @40,
			@"2002:c000::" : @40,
			@"2002:c0a8::" : @32,
			@"2002:c612::" : @31,
			@"2002:c633:6400::" : @40,
			@"2002:cb00:7100::" : @40,
			@"2002:e000::" : @20,
			@"2002:f000::" : @20,
			@"2002:ffff:ffff::" : @48,
		} enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
			struct in6_addr addr;
			struct in6_addr mask = { 0 }, network = { 0 }, broadcast = { 0 };
			int i, j;

			if (inet_pton(AF_INET6, [key UTF8String], &addr) != 0) {
				for (i = [(NSNumber *)value intValue], j = 0; i > 0; i -= 8, j++) {
					if (i >= 8)
						mask.s6_addr[j] = 0xff;
					else
						mask.s6_addr[j] = (unsigned long)(0xffU << (8 - i));
				}
				
				for (i = 0; i < sizeof(struct in6_addr); i++)
					network.s6_addr[i] = addr.s6_addr[i] & mask.s6_addr[i];

				memcpy(&broadcast, &network, sizeof(struct in6_addr));
				
				for (i = 0; i < sizeof(struct in6_addr); i++)
					broadcast.s6_addr[i] |= ~mask.s6_addr[i];
				
				[tLocal6Nets addObject:@[ [NSValue valueWithBytes:&network objCType:@encode(struct in6_addr)], [NSValue valueWithBytes:&broadcast objCType:@encode(struct in6_addr)], key, value ]];
			} else {
				NSLog(@"[LocalNetworkChecker] failed parsing IPv6 IP %@", key);
				abort();
			}
		}];
		
		local6Nets = [NSArray arrayWithArray:tLocal6Nets];
	}
	
	NSArray *ips = [[self class] addressesForHostname:host];
	if (ips == nil)
		return NO;
	
	for (NSString *ip in ips) {
		struct addrinfo hint, *res = NULL;
		int ret, family;
		
		memset(&hint, '\0', sizeof hint);

		hint.ai_family = PF_UNSPEC;
		hint.ai_flags = AI_NUMERICHOST;
		
		ret = getaddrinfo([ip UTF8String], NULL, &hint, &res);
		if (ret) {
			NSLog(@"[LocalNetworkChecker] DNS returned invalid address \"%@\"", ip);
			continue;
		}
		
		family = res->ai_family;
		freeaddrinfo(res);

		if (family == AF_INET) {
			struct in_addr addr;

			if (inet_aton([ip UTF8String], &addr) != 1) {
				NSLog(@"[LocalNetworkChecker: failed parsing ip \"%@\"", ip);
				continue;
			}
			
			uint32_t uip = ntohl(addr.s_addr);
			
			for (NSArray *net in localNets) {
				if (uip >= [((NSNumber *)net[0]) intValue] && uip <= [((NSNumber *)net[1]) intValue]) {
#ifdef TRACE
					NSLog(@"[LocalNetworkChecker] ip %@ is in local network %@/%@ (%@-%@)", ip, net[2], net[3], net[0], net[1]);
#endif
					return YES;
				}
			}
		}
		else if (family == AF_INET6) {
			struct in6_addr addr;
			
			if (inet_pton(AF_INET6, [ip UTF8String], &addr) != 1) {
				NSLog(@"[LocalNetworkChecker: failed parsing ipv6 ip \"%@\"", ip);
				continue;
			}
			
			for (NSArray *net in local6Nets) {
				struct in6_addr network = { 0 }, broadcast = { 0 };

				NSValue *n = [net objectAtIndex:0];
				NSValue *b = [net objectAtIndex:1];
				[n getValue:&network];
				[b getValue:&broadcast];
				
				for (int i = 0; i <= 16; i += 2) {
					if (i == 16) {
#ifdef TRACE
						NSLog(@"[LocalNetworkChecker] ipv6 ip %@ is in %@/%@", ip, [net objectAtIndex:2], [net objectAtIndex:3]);
#endif
						return YES;
					}
					
					if (!((int)((addr.s6_addr[i] << 8) + addr.s6_addr[i + 1]) >= (int)((network.s6_addr[i] << 8) + network.s6_addr[i + 1]) &&
					    (int)((addr.s6_addr[i] << 8) + addr.s6_addr[i + 1]) <= (int)((broadcast.s6_addr[i] << 8) + broadcast.s6_addr[i + 1])))
						break;
				}
			}
		} else {
			NSLog(@"[LocalNetworkChecker] invalid family %d for %@", family, ip);
		}
	}
	
	return NO;
}

@end
