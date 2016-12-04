// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// This file is derived from Punycode-Cocoa, under an MIT-style License.
// Copyright 2005-2012 Derailer. All rights reserved.
// See https://github.com/Wevah/Punycode-Cocoa/blob/master/LICENSE

#import <Foundation/Foundation.h>


@interface NSString (PunycodeAdditions)

- (NSString *)punycodeEncodedString;
- (NSString *)punycodeDecodedString;

- (NSString *)IDNAEncodedString;
- (NSString *)IDNADecodedString;

// These methods currently expect self to start with a valid scheme.
- (NSString *)encodedURLString;
- (NSString *)decodedURLString;

@end

@interface NSURL (PunycodeAdditions)

+ (NSURL *)URLWithUnicodeString:(NSString *)URLString;
- (NSString *)decodedURLString;

@end
