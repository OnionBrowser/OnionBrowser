/*
 * Endless
 * Copyright (c) 2014-2017 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "CookieJar.h"
#import "HostSettings.h"
#import "HTTPSEverywhere.h"

/*
 * local storage is found in NSCachesDirectory and can be a file or directory:
 *
 * endlessproxys_www.google.com_0.localstorage
 * https_m.imgur.com_0.localstorage
 * https_m.youtube.com_0.localstorage
 * http_samy.pl_0/
 * http_samy.pl_0/.lock
 * http_samy.pl_0/0000000000000001.db
 * http_samy.pl_0.localstorage
 * https_samy.pl_0.localstorage-shm
 * https_samy.pl_0.localstorage-wal
 * ___IndexedDB/
 * ___IndexedDB/http_nparashuram.com_0/BookShop1/IndexedDB.sqlite3
 * ___IndexedDB/http_nparashuram.com_0/BookShop1/IndexedDB.sqlite3-shm
 *
 * the root-level "Databases.db(-(shm|wal))?" file contains references to other files
 */

#define LOCAL_STORAGE_REGEX @"^(___IndexedDB/)?(https?|endless[a-z]*?)_(.+)_\\d+"

/* the capture group of the above that extracts the hostname */
#define LOCAL_STORAGE_REGEX_HOSTNAME_GROUP 3

/* files we'll exclude from a deep-clean of the cache directory */
#define CACHE_EXCLUSIONS_REGEX @"^(org.jcs.endless/HSTS\\.plist|Databases\\.db(-shm|wal)?|Snapshots/.*)$"

@implementation CookieJar {
	AppDelegate *appDelegate;
}

- (CookieJar *)init
{
	self = [super init];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

	_cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
	[_cookieStorage setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];

	_dataAccesses = [[NSMutableDictionary alloc] init];
	
	/* TODO: eventually remove this in a future version */
	{
		/* migrate old whitelist entries to new HostSettings entries */
		NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
		NSString *whitelist = [path stringByAppendingPathComponent:@"cookie_whitelist.plist"];
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if ([fileManager fileExistsAtPath:whitelist]) {
			NSDictionary *list = [NSDictionary dictionaryWithContentsOfFile:whitelist];
			
			NSLog(@"[CookieJar] migrating old cookie whitelist to HostSettings: %@", list);
			for (NSString *host in [list allKeys]) {
				HostSettings *hc = [HostSettings forHost:host];
				if (hc == nil)
					hc = [[HostSettings alloc] initForHost:host withDict:nil];
				
				[hc setSetting:HOST_SETTINGS_KEY_WHITELIST_COOKIES toValue:HOST_SETTINGS_VALUE_YES];
				[hc save];
			}
			
			[HostSettings persist];
			[fileManager removeItemAtPath:whitelist error:nil];
		}
	}
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[self setOldDataSweepTimeout:[NSNumber numberWithInteger:[userDefaults integerForKey:@"old_data_sweep_mins"]]];
	
	return self;
}

- (BOOL)isHostWhitelisted:(NSString *)host
{
	host = [host lowercaseString];
	
	HostSettings *hs = [HostSettings forHost:host];
	if (hs && [hs boolSettingOrDefault:HOST_SETTINGS_KEY_WHITELIST_COOKIES]) {
#ifdef TRACE_COOKIE_WHITELIST
		NSLog(@"[CookieJar] found entry for %@", host);
#endif
		return YES;
	}
	
	/* for a cookie host of x.y.z.example.com, try y.z.example.com, z.example.com, example.com, etc. */
	NSArray *hostp = [host componentsSeparatedByString:@"."];
	for (int i = 1; i < [hostp count]; i++) {
		NSString *wc = [[hostp subarrayWithRange:NSMakeRange(i, [hostp count] - i)] componentsJoinedByString:@"."];

		if ((hs = [HostSettings forHost:wc]) && [hs boolSettingOrDefault:HOST_SETTINGS_KEY_WHITELIST_COOKIES]) {
#ifdef TRACE_COOKIE_WHITELIST
			NSLog(@"[CookieJar] found entry for component %@ in %@", wc, host);
#endif
			return YES;
		}
	}
	
	/* no match for any of these hosts, use the default */
	hs = [HostSettings defaultHostSettings];
	return [hs boolSettingOrDefault:HOST_SETTINGS_KEY_WHITELIST_COOKIES];
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

- (NSDictionary *)localStorageFiles
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	
	NSMutableDictionary *files = [[NSMutableDictionary alloc] init];
	
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:LOCAL_STORAGE_REGEX options:0 error:nil];
	
	NSRegularExpression *ignoreRegex = [NSRegularExpression regularExpressionWithPattern:CACHE_EXCLUSIONS_REGEX options:0 error:nil];

	for (NSString *file in [fm subpathsAtPath:cacheDir]) {
		if ([ignoreRegex numberOfMatchesInString:file options:0 range:NSMakeRange(0, [file length])] > 0) {
#ifdef TRACE_COOKIES
			NSLog(@"[CookieJar] excluding file from sweep: %@", file);
#endif
			continue;
		}
		
		NSString *absFile = [NSString stringWithFormat:@"%@/%@", cacheDir, file];

		NSArray *matches = [regex matchesInString:file options:0 range:NSMakeRange(0, [file length])];
		if (!matches || ![matches count]) {
			[files setObject:NSLocalizedString(@"(Other cache data)", nil) forKey:absFile];
			continue;
		}
		
		for (NSTextCheckingResult *match in matches) {
			if ([match numberOfRanges] >= 1) {
				NSString *host = [file substringWithRange:[match rangeAtIndex:LOCAL_STORAGE_REGEX_HOSTNAME_GROUP]];
				[files setObject:host forKey:absFile];
			}
		}
	}

	return files;
}

- (NSArray *)localStorageHosts
{
	NSMutableArray *hosts = [[NSMutableArray alloc] init];
	NSDictionary *files = [self localStorageFiles];
	
	for (NSString *file in [files allKeys]) {
		NSString *host = [files objectForKey:file];
		
		if (![hosts containsObject:host]) {
			[hosts addObject:host];
		}
	}

	return [hosts sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (NSArray *)cookiesForURL:(NSURL *)url forTab:(NSUInteger)tabHash
{
	NSArray *c = [[self cookieStorage] cookiesForURL:url];
	
	for (NSHTTPCookie *cookie in c) {
		[self trackDataAccessForDomain:[cookie domain] fromTab:tabHash];
	}

	return c;
}

- (void)setCookies:(NSArray *)cookies forURL:(NSURL *)URL mainDocumentURL:(NSURL *)mainDocumentURL forTab:(NSUInteger)tabHash
{
	NSMutableArray *newCookies = [[NSMutableArray alloc] initWithCapacity:[cookies count]];
	
	for (NSHTTPCookie *cookie in cookies) {
		NSMutableDictionary *ps = (NSMutableDictionary *)[cookie properties];
		
		if (![cookie isSecure] && [HTTPSEverywhere needsSecureCookieFromHost:[URL host] forHost:[cookie domain] cookieName:[cookie name]]) {
			/* toggle "secure" bit */
			[ps setValue:@"TRUE" forKey:NSHTTPCookieSecure];
		}
		
		NSHTTPCookie *nCookie = [[NSHTTPCookie alloc] initWithProperties:ps];
		[newCookies addObject:nCookie];
		
		[self trackDataAccessForDomain:[cookie domain] fromTab:tabHash];
	}
	
	if ([newCookies count] > 0) {
#ifdef TRACE_COOKIES
		NSLog(@"[CookieJar] [Tab h%lu] storing %lu cookie(s) for %@ (via %@)", tabHash, [newCookies count], [URL host], mainDocumentURL);
#endif
		[[self cookieStorage] setCookies:newCookies forURL:URL mainDocumentURL:mainDocumentURL];
	}
}

- (void)trackDataAccessForDomain:(NSString *)domain fromTab:(NSUInteger)tabHash
{
	NSNumber *tabHashN = [NSNumber numberWithLong:tabHash];
	NSInteger now = (NSInteger)[[NSDate date] timeIntervalSince1970];
	
	if (![[self dataAccesses] objectForKey:tabHashN])
		[[self dataAccesses] setObject:[[NSMutableDictionary alloc] init] forKey:tabHashN];
	
	NSNumber *lastAccess = [[[self dataAccesses] objectForKey:tabHashN] objectForKey:domain];
	if (lastAccess != nil && ([lastAccess longValue] == now))
		return;
	
	[(NSMutableDictionary *)[[self dataAccesses] objectForKey:tabHashN] setObject:[NSNumber numberWithLong:now] forKey:domain];
	
#ifdef TRACE_COOKIES
	NSLog(@"[CookieJar] [Tab h%lu] touched data access for %@", tabHash, domain);
#endif
}

/* ignores whitelist, this is forced by the user */
- (void)clearAllDataForHost:(NSString *)host
{
	for (NSHTTPCookie *cookie in [[self cookieStorage] cookies]) {
		if ([[cookie domain] isEqualToString:host] || [[cookie domain] isEqualToString:[NSString stringWithFormat:@".%@", host]]) {
#ifdef TRACE_COOKIES
			NSLog(@"[CookieJar] deleting cookie for %@: %@", host, cookie);
#endif
			[[self cookieStorage] deleteCookie:cookie];
		}
	}
	
	NSDictionary *allFiles = [self localStorageFiles];
	
	/* sort filenames by length descending, so we're always deleting files in a dir before the dir itself */
	NSArray *files = [[allFiles allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
		return [[NSNumber numberWithLong:[(NSString *)b length]] compare:[NSNumber numberWithLong:[(NSString *)a length]]];
	}];
	
	for (NSString *file in files) {
		NSString *fhost = [allFiles objectForKey:file];
		
		if ([host isEqualToString:fhost]) {
#ifdef TRACE_COOKIES
			NSLog(@"[CookieJar] deleting local storage for %@: %@", host, file);
#endif
			[[NSFileManager defaultManager] removeItemAtPath:file error:nil];
		}
	}
}

- (void)clearAllNonWhitelistedCookiesOlderThan:(NSTimeInterval)secs
{
	for (NSHTTPCookie *cookie in [[self cookieStorage] cookies]) {
		if ([self isHostWhitelisted:[cookie domain]]) {
			continue;
		}
		
		NSNumber *blocker;
		
		if (secs > 0) {
			for (NSNumber *tabHashN in [[self dataAccesses] allKeys]) {
				NSMutableDictionary *tabCookies = [[self dataAccesses] objectForKey:tabHashN];
				NSDate *la = [tabCookies objectForKey:[cookie domain]];
				if (la != nil || [[NSDate date] timeIntervalSinceDate:la] < secs) {
					blocker = tabHashN;
					break;
				}
			}
		}

		if (secs == 0 || blocker == nil) {
#ifdef TRACE_COOKIE_WHITELIST
			NSLog(@"[CookieJar] deleting non-whitelisted cookie: %@", cookie);
#endif
			[[self cookieStorage] deleteCookie:cookie];
		}
	}
}

- (void)clearAllNonWhitelistedLocalStorageOlderThan:(NSTimeInterval)secs
{
	NSDictionary *allFiles = [self localStorageFiles];
	
	/* sort filenames by length descending, so we're always deleting files in a dir before the dir itself */
	NSArray *files = [[allFiles allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
		return [[NSNumber numberWithLong:[(NSString *)b length]] compare:[NSNumber numberWithLong:[(NSString *)a length]]];
	}];
	
	for (NSString *file in files) {
		NSString *fhost = [allFiles objectForKey:file];
		
		if ([self isHostWhitelisted:fhost]) {
			continue;
		}

		NSNumber *blocker;
		
		if (secs > 0) {
			for (NSNumber *tabHashN in [[self dataAccesses] allKeys]) {
				NSMutableDictionary *tabData = [[self dataAccesses] objectForKey:tabHashN];
				NSDate *la = [tabData objectForKey:fhost];
				if (la != nil || [[NSDate date] timeIntervalSinceDate:la] < secs) {
#ifdef TRACE_COOKIES
					NSLog(@"[CookieJar] tab %@ blocking sweep of >%f secs", tabHashN, secs);
#endif
					blocker = tabHashN;
					break;
				}
			}
		}
		
		if (secs == 0 || blocker == nil) {
#ifdef TRACE_COOKIES
			NSLog(@"[CookieJar] deleting local storage for %@: %@", fhost, file);
#endif
			[[NSFileManager defaultManager] removeItemAtPath:file error:nil];
		}
	}
}

- (void)clearAllNonWhitelistedData
{
	[self clearAllNonWhitelistedCookiesOlderThan:0];
	[self clearAllNonWhitelistedLocalStorageOlderThan:0];
}

- (void)clearAllOldNonWhitelistedData
{
	int sweepmins = [[self oldDataSweepTimeout] intValue];
	
#ifdef TRACE_COOKIES
	NSLog(@"[CookieJar] clearing non-whitelisted data older than %d min(s)", sweepmins);
#endif
	[self clearAllNonWhitelistedCookiesOlderThan:(60 * sweepmins)];
	[self clearAllNonWhitelistedLocalStorageOlderThan:(60 * sweepmins)];
}


- (void)clearNonWhitelistedDataForTab:(NSUInteger)tabHash
{
	NSNumber *tabHashN = [NSNumber numberWithLong:tabHash];

#ifdef TRACE_COOKIES
	NSLog(@"[Tab h%@] clearing non-whitelisted data", tabHashN);
#endif
	
	for (NSString *cookieDomain in [[[self dataAccesses] objectForKey:tabHashN] allKeys]) {
		NSNumber *blocker;

		for (NSNumber *otherTabHashN in [[self dataAccesses] allKeys]) {
			if ([otherTabHashN isEqual:tabHashN]) {
				continue;
			}
			
			NSMutableDictionary *tabCookies = [[self dataAccesses] objectForKey:otherTabHashN];
			
			if ([tabCookies objectForKey:cookieDomain]) {
				blocker = otherTabHashN;
				break;
			}
		}
		
		if (blocker) {
#ifdef TRACE_COOKIES
			NSLog(@"[Tab h%@] data for %@ in use on tab %@, not deleting", tabHashN, cookieDomain, blocker);
#endif
		}
		else if (![self isHostWhitelisted:cookieDomain]) {

#ifdef TRACE_COOKIES
			NSLog(@"[Tab h%@] deleting data for %@", tabHashN, cookieDomain);
#endif
			[self clearAllDataForHost:cookieDomain];
		}
	}
	
	[[self dataAccesses] removeObjectForKey:tabHashN];
}

@end
