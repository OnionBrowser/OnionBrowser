#import "AppDelegate.h"
#import "CookieJar.h"

/*
 * local storage is found in NSCachesDirectory and can be a file or directory:
 *
 * ./AppData/Library/Caches/https_m.imgur.com_0.localstorage
 * ./AppData/Library/Caches/https_m.youtube.com_0.localstorage
 * ./AppData/Library/Caches/http_samy.pl_0
 * ./AppData/Library/Caches/http_samy.pl_0/.lock
 * ./AppData/Library/Caches/http_samy.pl_0/0000000000000001.db
 * ./AppData/Library/Caches/http_samy.pl_0.localstorage
 */

#define LOCAL_STORAGE_REGEX @"/https?_(.+)_\\d+(\\.localstorage)?$"

@implementation CookieJar

AppDelegate *appDelegate;

+ (NSString *)cookieWhitelistPath
{
	NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	return [path stringByAppendingPathComponent:@"cookie_whitelist.plist"];
}

- (CookieJar *)init
{
	self = [super init];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	_cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	[_cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];

	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:[[self class] cookieWhitelistPath]]) {
		_whitelist = [NSMutableDictionary dictionaryWithContentsOfFile:[[self class] cookieWhitelistPath]];
	}
	else {
		_whitelist = [[NSMutableDictionary alloc] initWithCapacity:20];
	}
	
	return self;
}

- (void)persist
{
	[[self whitelist] writeToFile:[[self class] cookieWhitelistPath] atomically:YES];
}

- (BOOL)isHostWhitelisted:(NSString *)host
{
	host = [host lowercaseString];
	
	if ([[self whitelist] objectForKey:host]) {
#ifdef TRACE_COOKIE_WHITELIST
		NSLog(@"[CookieJar] found entry for %@", host);
#endif
		return YES;
	}
	
	/* for a cookie host of x.y.z.example.com, try y.z.example.com, z.example.com, example.com, etc. */
	NSArray *hostp = [host componentsSeparatedByString:@"."];
	for (int i = 1; i < [hostp count]; i++) {
		NSString *wc = [[hostp subarrayWithRange:NSMakeRange(i, [hostp count] - i)] componentsJoinedByString:@"."];
		
		if ([[self whitelist] objectForKey:wc]) {
#ifdef TRACE_COOKIE_WHITELIST
			NSLog(@"[CookieJar] found entry for component %@ in %@", wc, host);
#endif
			return YES;
		}
	}
	
	return NO;
}

- (NSArray *)whitelistedHosts
{
	return [NSArray arrayWithArray:[[[self whitelist] allKeys] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]];
}

- (void)clearAllNonWhitelistedCookies
{
	for (NSHTTPCookie *cookie in [[self cookieStorage] cookies]) {
		if (![self isHostWhitelisted:cookie.domain]) {
#ifdef TRACE_COOKIE_WHITELIST
			NSLog(@"[CookieJar] deleting non-whitelisted cookie: %@", cookie);
#endif
			[[self cookieStorage] deleteCookie:cookie];
		}
	}
}

- (void)clearAllNonWhitelistedLocalStorage
{
	for (NSString *file in [self localStorageFiles]) {
#ifdef TRACE_COOKIES
		NSLog(@"[CookieJar] deleting local storage: %@", file);
#endif
		[[NSFileManager defaultManager] removeItemAtPath:file error:nil];
	}
}

- (void)clearTransientData
{
	[self clearAllNonWhitelistedCookies];
	[self clearAllNonWhitelistedLocalStorage];
}

- (void)clearTransientDataForHost:(NSString *)host
{
	for (NSHTTPCookie *cookie in [[self cookieStorage] cookies]) {
		if ([[cookie domain] isEqualToString:host] || [[cookie domain] isEqualToString:[NSString stringWithFormat:@".%@", host]]) {
#ifdef TRACE_COOKIES
			NSLog(@"[CookieJar] deleting cookie for %@: %@", host, cookie);
#endif
			[[self cookieStorage] deleteCookie:cookie];
		}
	}
	
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:LOCAL_STORAGE_REGEX options:0 error:nil];

	for (NSString *file in [self localStorageFiles]) {
		NSArray *matches = [regex matchesInString:file options:0 range:NSMakeRange(0, [file length])];
		if (!matches || ![matches count]) {
			continue;
		}
		for (NSTextCheckingResult *match in matches) {
			if ([match numberOfRanges] >= 1) {
				if ([host isEqualToString:[file substringWithRange:[match rangeAtIndex:1]]]) {
#ifdef TRACE_COOKIES
					NSLog(@"[CookieJar] deleting local storage for %@: %@", host, file);
#endif
					[[NSFileManager defaultManager] removeItemAtPath:file error:nil];
				}
			}
		}
	}
}

- (NSArray *)sortedHostCounts
{
	NSMutableDictionary *cHostCount = [[NSMutableDictionary alloc] init];
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\." options:0 error:nil];
	NSMutableArray *sortedCookieHosts;
	
	for (NSHTTPCookie *c in [[self cookieStorage] cookies]) {
		/* strip off leading . */
		NSString *cdomain = [regex stringByReplacingMatchesInString:[c domain] options:0 range:NSMakeRange(0, [[c domain] length]) withTemplate:@""];
		
		NSNumber *count = @0;

		NSDictionary *cct = [cHostCount objectForKey:cdomain];
		if (cct)
			count = [cct objectForKey:@"cookies"];
		
		[cHostCount setObject:@{ @"cookies" : [NSNumber numberWithInt:[count intValue] + 1] } forKey:cdomain];
	}
	
	/* mix in localstorage */
	for (NSString *host in [self localStorageHosts]) {
		[cHostCount setObject:@{ @"localStorage" : [NSNumber numberWithInt:1] } forKey:host];
	}

	sortedCookieHosts = [[NSMutableArray alloc] initWithCapacity:[cHostCount count]];
	for (NSString *cdomain in [[cHostCount allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]) {
		[sortedCookieHosts addObject:@{ cdomain : [cHostCount objectForKey:cdomain] }];
	}
	
	return sortedCookieHosts;
}

- (NSArray *)localStorageFiles
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:LOCAL_STORAGE_REGEX options:0 error:nil];
	
	NSMutableArray *files = [[NSMutableArray alloc] init];
	
	for (NSString *file in [fm contentsOfDirectoryAtPath:cacheDir error:nil]) {
		NSString *absFile = [NSString stringWithFormat:@"%@/%@", cacheDir, file];
		
		NSArray *matches = [regex matchesInString:absFile options:0 range:NSMakeRange(0, [absFile length])];
		if (matches && [matches count] > 0) {
			[files addObject:absFile];
		}
	}
	
	return files;
}

- (NSArray *)localStorageHosts
{
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:LOCAL_STORAGE_REGEX options:0 error:nil];
	
	NSMutableArray *hosts = [[NSMutableArray alloc] init];

	for (NSString *file in [self localStorageFiles]) {
		NSArray *matches = [regex matchesInString:file options:0 range:NSMakeRange(0, [file length])];
		if (!matches || ![matches count]) {
			continue;
		}
		
		for (NSTextCheckingResult *match in matches) {
			if ([match numberOfRanges] >= 1) {
				NSString *host = [file substringWithRange:[match rangeAtIndex:1]];
				
				if (![hosts containsObject:host]) {
					[hosts addObject:host];
				}
			}
		}
	}

	return [hosts sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

/* swap out entire whitelist */
- (void)updateWhitelistedHostsWithArray:(NSArray *)hosts
{
	for (NSString *host in hosts) {
		if (![[self whitelist] objectForKey:host]) {
			[[self whitelist] setValue:@YES forKey:[host lowercaseString]];
		}
	}
	
	for (NSString *host in [[self whitelist] allKeys]) {
		if ([hosts indexOfObject:host] == NSNotFound) {
			[[self whitelist] removeObjectForKey:host];
		}
	}
}

- (NSArray *)cookiesForURL:(NSURL *)url
{
	return [[self cookieStorage] cookiesForURL:url];
}

- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)URL mainDocumentURL:(NSURL *)mainDocumentURL
{
	[[self cookieStorage] setCookies:cookies forURL:URL mainDocumentURL:mainDocumentURL];

}

@end
