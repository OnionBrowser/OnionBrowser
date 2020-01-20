/*
 * Onion Browser
 * Copyright (c) 2012-2018, Tigas Ventures, LLC (Mike Tigas)
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>
#import "OBSettingsConstants.h"

NSString *const IPV4V6 = @"ipv4v6";
NSString *const LOCALE = @"locale";

// Choices for IPV4V6
NSInteger const IPV4V6_AUTO = 0;
NSInteger const IPV4V6_V4ONLY = 1;
NSInteger const IPV4V6_V6ONLY = 2;
NSInteger const IPV4V6_FORCEDUAL = 3;
