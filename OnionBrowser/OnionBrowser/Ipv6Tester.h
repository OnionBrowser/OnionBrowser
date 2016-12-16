// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "Reachability.h"

#define TOR_IPV6_CONN_FALSE 0
#define TOR_IPV6_CONN_DUAL 1
#define TOR_IPV6_CONN_ONLY 2
#define TOR_IPV6_CONN_UNKNOWN 99

@interface Ipv6Tester : NSObject

+ (NSInteger) ipv6_status;

@end
