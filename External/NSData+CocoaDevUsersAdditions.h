/*
 * Based on public domain example and information on the CocoaDev Wiki:
 * http://cocoadev.com/wiki/NSDataCategory
 */

#import <Foundation/Foundation.h>

@interface NSData (NSDataExtension)

- (NSData *) zlibInflate;
- (NSData *) gzipInflate;

@end
