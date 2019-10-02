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

#import "CertificateAuthentication.h"

NSString* _Nonnull const OCSPCacheUserDefaultsKey = @"OCSPCache.ocsp_cache_1";

@implementation CertificateAuthentication

- (instancetype)init {
	self = [super init];

	if (self) {
		void (^ocspLogger)(NSString * _Nonnull logLine) = nil;

#ifdef TRACE
		ocspLogger =
		^(NSString * _Nonnull logLine) {
			NSLog(@"[OCSPCache] %@", logLine);
		};
#endif

		self.ocspCache =
		[[OCSPCache alloc] initWithLogger:ocspLogger
				  andLoadFromUserDefaults:[NSUserDefaults standardUserDefaults]
								  withKey:OCSPCacheUserDefaultsKey];

		void (^authLogger)(NSString * _Nonnull logLine) = nil;

#ifdef TRACE
		authLogger =
		^(NSString * _Nonnull logLine) {
			NSLog(@"[ServerTrust] %@", logLine);
		};
#endif


		self.authURLSessionDelegate =
		[[OCSPAuthURLSessionDelegate alloc] initWithLogger:authLogger
												 ocspCache:self.ocspCache
											 modifyOCSPURL:nil
												   session:nil
												   timeout:1];

	}

	return self;
}

- (void)persist {
	[self.ocspCache persistToUserDefaults:[NSUserDefaults standardUserDefaults]
								  withKey:OCSPCacheUserDefaultsKey];
}

+ (void)deletePersistedData {
	[[NSUserDefaults standardUserDefaults] removeObjectForKey:OCSPCacheUserDefaultsKey];
}

@end
