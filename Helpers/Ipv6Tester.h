/*
 * Onion Browser
 * Copyright (c) 2012-2018, Tigas Ventures, LLC (Mike Tigas)
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>
#import "Reachability.h"

#define TOR_IPV6_CONN_FALSE 0
#define TOR_IPV6_CONN_DUAL 1
#define TOR_IPV6_CONN_ONLY 2
#define TOR_IPV6_CONN_UNKNOWN 99

@interface Ipv6Tester : NSObject

+ (NSInteger) ipv6_status;

@end
