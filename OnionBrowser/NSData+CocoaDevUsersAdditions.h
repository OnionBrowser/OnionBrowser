/*
 * Based on public domain example and information on the CocoaDev Wiki:
 * http://cocoadev.com/wiki/NSDataCategory
 */
 #import <Foundation/Foundation.h>


@interface NSData (NSDataExtension)

// Returns range [start, null byte), or (NSNotFound, 0).
- (NSRange) rangeOfNullTerminatedBytesFrom:(int)start;

// Canonical Base32 encoding/decoding.
+ (NSData *) dataWithBase32String:(NSString *)base32;
- (NSString *) base32String;

- (NSData *) zlibInflate;
- (NSData *) gzipInflate;

@end