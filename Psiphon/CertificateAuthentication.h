/*
 * Copyright (c) 2019, Psiphon Inc.
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

#import "OCSPAuthURLSessionDelegate.h"
#import "OCSPCache.h"

NS_ASSUME_NONNULL_BEGIN


/**
 Interface to OCSPCache
 */
@interface CertificateAuthentication : NSObject

@property OCSPAuthURLSessionDelegate *authURLSessionDelegate;
@property OCSPCache *ocspCache;

- (void)persist;

+ (void)deletePersistedData;

@end

NS_ASSUME_NONNULL_END
