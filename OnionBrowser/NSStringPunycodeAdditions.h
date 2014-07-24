//
//  NSStringPunycodeAdditions.h
//  Punycode
//  https://github.com/Wevah/Punycode-Cocoa
//
//  Created by Wevah on 2005.11.02.
//  Copyright 2005-2012 Derailer. All rights reserved.
//
//  Distributed under an MIT-style license.
//  See https://github.com/Wevah/Punycode-Cocoa/blob/master/LICENSE
//

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
