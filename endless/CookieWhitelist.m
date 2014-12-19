#import "CookieWhitelist.h"

@implementation CookieWhitelist

+ (NSString *)cookieWhitelistPath
{
	NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	return [path stringByAppendingPathComponent:@"cookie_whitelist.plist"];
}

- (CookieWhitelist *)init
{
	self = [super init];
	_dict = [[NSMutableDictionary alloc] init];
	return self;
}

+ (CookieWhitelist *)retrieve
{
	CookieWhitelist *cw = [[CookieWhitelist alloc] init];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:[[self class] cookieWhitelistPath]]) {
		cw.dict = [NSMutableDictionary dictionaryWithContentsOfFile:[[self class] cookieWhitelistPath]];
	}
	else {
		cw.dict = [[NSMutableDictionary alloc] initWithCapacity:20];
	}
	
	return cw;
}

- (void)persist
{
	[self writeToFile:[[self class] cookieWhitelistPath] atomically:YES];
}

- (void)updateHostsWithArray:(NSArray *)hosts
{
	for (NSString *host in hosts) {
		if (![self objectForKey:host]) {
			[self setValue:@YES forKey:[host lowercaseString]];
		}
	}
	
	for (NSString *host in [self allKeys]) {
		if ([hosts indexOfObject:host] == NSNotFound) {
			[self removeObjectForKey:host];
		}
	}
}

- (BOOL)isHostWhitelisted:(NSString *)host
{
	host = [host lowercaseString];
	
	if ([self objectForKey:host]) {
#ifdef TRACE_COOKIE_WHITELIST
		NSLog(@"[CookieWhitelist] found entry for %@", host);
#endif
		return YES;
	}
	
	/* for a cookie host of x.y.z.example.com, try .y.z.example.com, .z.example.com, .example.com, etc. */
	NSArray *hostp = [host componentsSeparatedByString:@"."];
	for (int i = 1; i < [hostp count]; i++) {
		NSString *wc = [[hostp subarrayWithRange:NSMakeRange(i, [hostp count] - i)] componentsJoinedByString:@"."];
		
		if ([self objectForKey:wc]) {
#ifdef TRACE_COOKIE_WHITELIST
			NSLog(@"[CookieWhitelist] found entry for component %@ in %@", wc, host);
#endif
			return YES;
		}
	}
	
	return NO;
}


/* NSMutableDictionary composition pass-throughs */

- (id)objectForKey:(id)aKey
{
	return [[self dict] objectForKey:aKey];
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
	return [[self dict] writeToFile:path atomically:useAuxiliaryFile];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
	[[self dict] setValue:value forKey:key];
}

- (void)removeObjectForKey:(id)aKey
{
	[[self dict] removeObjectForKey:aKey];
}

- (NSArray *)allKeys
{
	return [[self dict] allKeys];
}

@end
