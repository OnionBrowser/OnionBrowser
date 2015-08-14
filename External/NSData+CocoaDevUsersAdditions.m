/*
 * Based on public domain example and information on the CocoaDev Wiki:
 * http://cocoadev.com/wiki/NSDataCategory
 */

#import "NSData+CocoaDevUsersAdditions.h"
#include <zlib.h>

#define FUNC_GZIP 2
#define FUNC_INFLATE 1

@implementation NSData (NSDataExtension)

- (NSData *)inflateWithFunction:(int)func
{
	if ([self length] == 0)
		return self;
	
	unsigned int full_length = (unsigned int)[self length];
	unsigned int half_length = (unsigned int)([self length] / 2);
	
	NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
	BOOL done = NO;
	int status;
	
	z_stream strm;
	strm.next_in = (Bytef *)[self bytes];
	strm.avail_in = (unsigned int)[self length];
	strm.total_out = 0;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	
	if (func == FUNC_INFLATE) {
		if (inflateInit(&strm) != Z_OK)
			return nil;
	}
	else if (func == FUNC_GZIP) {
		if (inflateInit2(&strm, (15+32)) != Z_OK)
			return nil;
	}
	else
		return nil;
	
	while (!done) {
		// Make sure we have enough room and reset the lengths.
		if (strm.total_out >= [decompressed length])
			[decompressed increaseLengthBy: half_length];
		strm.next_out = [decompressed mutableBytes] + strm.total_out;
		strm.avail_out = (unsigned int)([decompressed length] - strm.total_out);
		
		// Inflate another chunk.
		status = inflate(&strm, Z_SYNC_FLUSH);
		if (status == Z_STREAM_END)
			done = YES;
		else if (status != Z_OK)
			break;
	}
	if (inflateEnd(&strm) != Z_OK)
		return nil;
	
	// Set real length.
	if (done) {
		[decompressed setLength:strm.total_out];
		return [NSData dataWithData:decompressed];
	}
	
	return nil;
}

- (NSData *)zlibInflate
{
	return [self inflateWithFunction:FUNC_INFLATE];
}

- (NSData *)gzipInflate
{
	return [self inflateWithFunction:FUNC_GZIP];
}

@end
