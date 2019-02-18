/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "HSTSCache.h"
#import "NSString+IPAddress.h"

/* rfc6797 HTTP Strict Transport Security */

/* note that UIWebView has its own HSTS cache that comes preloaded with a big plist of hosts, but we can't change it or manually add to it */

@implementation HSTSCache {
	AppDelegate *appDelegate;
}
static NSDictionary *_preloadedHosts;

+ (NSString *)hstsCachePath
{
	NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	return [path stringByAppendingPathComponent:@"hsts_cache.plist"];
}

- (HSTSCache *)init
{
	self = [super init];
	
	_dict = [[NSMutableDictionary alloc] init];
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	return self;
}

+ (HSTSCache *)retrieve
{
	HSTSCache *hc = [[HSTSCache alloc] init];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:[[self class] hstsCachePath]]) {
		hc.dict = [NSMutableDictionary dictionaryWithContentsOfFile:[[self class] hstsCachePath]];
	}
	else {
		hc.dict = [[NSMutableDictionary alloc] initWithCapacity:50];
	}
	
	/* mix in preloaded */
	NSString *path = [[NSBundle mainBundle] pathForResource:@"hsts_preload" ofType:@"plist"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
		NSDictionary *tmp = [NSDictionary dictionaryWithContentsOfFile:path];
		for (NSString *host in [tmp allKeys]) {
			NSDictionary *hostdef = [tmp objectForKey:host];
			NSMutableDictionary *v = [[NSMutableDictionary alloc] init];
			
			[v setObject:[NSDate dateWithTimeIntervalSinceNow:(60 * 60 * 24 * 365)] forKey:HSTS_KEY_EXPIRATION];
			[v setObject:@YES forKey:HSTS_KEY_PRELOADED];
			
			NSNumber *is = [hostdef objectForKey:@"include_subdomains"];
			if ([is intValue] == 1) {
				[v setObject:@YES forKey:HSTS_KEY_ALLOW_SUBDOMAINS];
			}
			
			[[hc dict] setObject:v forKey:host];
		}
		
#ifdef TRACE_HSTS
		NSLog(@"[HSTSCache] locked and loaded with %lu preloaded hosts", [tmp count]);
#endif
	}
	else {
		NSLog(@"[HSTSCache] no preload plist at %@", path);
	}
	
	return hc;
}

- (void)persist
{
	@try {
		[self writeToFile:[[self class] hstsCachePath] atomically:YES];
	}
	@catch(NSException *e) {
		NSLog(@"[HSTSCache] failed persisting to file: %@", e);
	}
}

- (NSURL *)rewrittenURI:(NSURL *)URL
{
	if (![[URL scheme] isEqualToString:@"http"]) {
		return URL;
	}
	
	NSString *host = [[URL host] lowercaseString];
	NSString *matchHost = [host copy];
	
	/* 8.3: ignore when host is a bare ip address */
	if ([host isValidIPAddress]) {
		return URL;
	}
	
	NSDictionary *params = [self objectForKey:host];
	if (params == nil) {
		/* for a host of x.y.z.example.com, try y.z.example.com, z.example.com, example.com, etc. */
		NSArray *hostp = [host componentsSeparatedByString:@"."];
		for (int i = 1; i < [hostp count]; i++) {
			NSString *wc = [[hostp subarrayWithRange:NSMakeRange(i, [hostp count] - i)] componentsJoinedByString:@"."];
			
			if (((params = [self objectForKey:wc]) != nil) && [params objectForKey:HSTS_KEY_ALLOW_SUBDOMAINS]) {
				matchHost = wc;
				break;
			}
		}
	}
	
	if (params != nil) {
		NSDate *exp = [params objectForKey:HSTS_KEY_EXPIRATION];
		if ([exp timeIntervalSince1970] < [[NSDate date] timeIntervalSince1970]) {
#ifdef TRACE_HSTS
			NSLog(@"[HSTSCache] entry for %@ expired at %@", matchHost, exp);
#endif
			[self removeObjectForKey:matchHost];
			params = nil;
		}
	}
	
	if (params == nil) {
		return URL;
	}
	
	NSURLComponents *URLc = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:NO];
	
	[URLc setScheme:@"https"];
	
	/* 8.3.5: nullify port unless it's a non-standard one */
	if ([URLc port] != nil && [[URLc port] intValue] == 80) {
		[URLc setPort:nil];
	}
	
#ifdef TRACE_HSTS
	NSLog(@"[HSTSCache] %@rewrote %@ to %@", ([params objectForKey:HSTS_KEY_PRELOADED] ? @"[preloaded] " : @""), URL, [URLc URL]);
#endif
	
	return [URLc URL];
}

- (void)parseHSTSHeader:(NSString *)header forHost:(NSString *)host
{
	NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithCapacity:3];
	host = [host lowercaseString];
	
	/* 8.1.1: reject caching when host is a bare ip address */
	if ([host isValidIPAddress])
		return;
	
#ifdef TRACE_HSTS
	NSLog(@"[HSTSCache] [%@] %@", host, header);
#endif

	NSArray *kvs = [header componentsSeparatedByString:@";"];
	for (NSString *kv in kvs) {
		NSArray *kvparts = [kv componentsSeparatedByString:@"="];
		NSString *key, *value;
		
		key = [kvparts[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		
		if ([kvparts count] > 1) {
			value = [[kvparts[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] stringByReplacingOccurrencesOfString:@"\"" withString:@""];
		}
		
		if ([[key lowercaseString] isEqualToString:@"max-age"]) {
			long long age = [value longLongValue];

			if (age == 0) {
#ifdef TRACE_HSTS
				NSLog(@"[HSTSCache] [%@] got max-age=0, deleting", host);
#endif
				/* TODO: if a preloaded entry exists, cache a negative entry */
				[self removeObjectForKey:host];
				return;
			}
			else {
				NSDate *expire = [[NSDate date] dateByAddingTimeInterval:age];
				[params setObject:expire forKey:HSTS_KEY_EXPIRATION];
			}
		}
		else if ([[key lowercaseString] isEqualToString:@"includesubdomains"]) {
			[params setObject:@YES forKey:HSTS_KEY_ALLOW_SUBDOMAINS];
		}
		else if ([[key lowercaseString] isEqualToString:@"preload"] ||
			 [[key lowercaseString] isEqualToString:@""]) {
			/* ignore */
		}
		else {
#ifdef TRACE_HSTS
			NSLog(@"[HSTSCache] [%@] unknown parameter \"%@\"", host, key);
#endif
		}
	}
	
	if ([params objectForKey:HSTS_KEY_EXPIRATION]) {
		[self setValue:params forKey:host];
	}
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
	if (value != nil && key != nil)
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
