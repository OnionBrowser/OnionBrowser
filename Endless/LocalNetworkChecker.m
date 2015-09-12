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
	if (!CFHostStartInfoResolution(hostRef, kCFHostAddresses, nil))
		return nil;
	
	CFArrayRef addressesRef = CFHostGetAddressing(hostRef, nil);
	if (addressesRef == nil)
		return nil;
	
	char ipAddress[INET6_ADDRSTRLEN];
	NSMutableArray *addresses = [NSMutableArray array];
	CFIndex numAddresses = CFArrayGetCount(addressesRef);
	for (CFIndex currentIndex = 0; currentIndex < numAddresses; currentIndex++) {
		struct sockaddr *address = (struct sockaddr *)CFDataGetBytePtr(CFArrayGetValueAtIndex(addressesRef, currentIndex));
		if (address == nil)
			return nil;
		
		if (getnameinfo(address, address->sa_len, ipAddress, INET6_ADDRSTRLEN, nil, 0, NI_NUMERICHOST) != 0)
			return nil;
		
		[addresses addObject:[NSString stringWithCString:ipAddress encoding:NSASCIIStringEncoding]];
	}
	
	[dnsCache setValue:@{ @"addresses" : addresses, @"time" : [NSDate date] } forKey:[host lowercaseString]];
	
	return addresses;
}

+ (BOOL)isHostOnLocalNet:(NSString *)host
{
	if (!localNets) {
		NSMutableArray *tLocalNets = [[NSMutableArray alloc] initWithCapacity:11];
		[@{
			/* rfc3330 */
			@"0.0.0.0" : @8,
			@"10.0.0.0" : @8,
			@"127.0.0.0" : @8,
			@"169.254.0.0" : @16,
			@"172.16.0.0" : @12,
			@"192.0.2.0" : @24,
			@"192.88.99.0" : @24,
			@"192.168.0.0" : @16,
			@"198.18.0.0" : @15,
			@"224.0.0.0" : @4,
			@"240.0.0.0" : @4,
		} enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
			struct in_addr addr;

			if (inet_aton([key UTF8String], &addr) != 0) {
				uint32_t ip = ntohl(addr.s_addr);
				int cidr = [(NSNumber *)value intValue];
				uint32_t last = ip + (uint32_t)pow(2, (32 - cidr)) - 1;
				
				[tLocalNets addObject:@[ [NSNumber numberWithInt:ip], [NSNumber numberWithInt:last] ]];
			}
		}];
		
		localNets = [NSArray arrayWithArray:tLocalNets];
	}
	
	NSArray *ips = [[self class] addressesForHostname:host];
	if (ips == nil)
		return NO;
	
	for (NSString *ip in ips) {
		struct in_addr addr;

		if (inet_aton([ip UTF8String], &addr) == 0) {
			continue;
		}
		uint32_t uip = ntohl(addr.s_addr);

		for (NSArray *net in localNets) {
			if (uip >= [((NSNumber *)net[0]) intValue] && uip <= [((NSNumber *)net[1]) intValue]) {
				return YES;
			}
		}
	}
	
	return NO;
}

@end
