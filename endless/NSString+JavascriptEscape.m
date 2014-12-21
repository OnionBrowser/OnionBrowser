#import "NSString+JavascriptEscape.h"

@implementation NSString (JavascriptEscape)

- (NSString *)stringEscapedForJavasacript {
	/* wrap in an array */
	NSArray *arrayForEncoding = @[ self ];
	
	/* encode to json */
	NSString *jsonString = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:arrayForEncoding options:0 error:nil] encoding:NSUTF8StringEncoding];
	
	/* then chop off the enclosing [] */
	return [jsonString substringWithRange:NSMakeRange(2, jsonString.length - 4)];
}

@end