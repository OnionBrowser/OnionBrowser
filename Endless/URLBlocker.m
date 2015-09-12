/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "URLBlocker.h"

@implementation URLBlocker

static NSDictionary *_targets;
static NSCache *ruleCache;

#define RULE_CACHE_SIZE 20

+ (NSDictionary *)targets
{
	if (_targets == nil) {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"urlblocker_targets" ofType:@"plist"];
		if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
			NSLog(@"[URLBlocker] no target plist at %@", path);
			abort();
		}
		
		_targets = [NSDictionary dictionaryWithContentsOfFile:path];
		
#ifdef TRACE_URL_BLOCKER
		NSLog(@"[URLBlocker] locked and loaded with %lu target domains", [_targets count]);
#endif
	}
	
	return _targets;
}

+ (void)cacheBlockedURL:(NSURL *)url withRule:(NSString *)rule
{
	if (!ruleCache) {
		ruleCache = [[NSCache alloc] init];
		[ruleCache setCountLimit:RULE_CACHE_SIZE];
	}
	
	[ruleCache setObject:rule forKey:url];
}

+ (NSString *)blockRuleForURL:(NSURL *)url
{
	NSString *blocker;
	
	if (!(ruleCache && (blocker = [ruleCache objectForKey:url]))) {
		NSString *host = [[url host] lowercaseString];
		
		blocker = [[[self class] targets] objectForKey:host];
		
		if (!blocker) {
			/* now for x.y.z.example.com, try *.y.z.example.com, *.z.example.com, *.example.com, etc. */
			/* TODO: should we skip the last component for obviously non-matching things like "*.com", "*.net"? */
			NSArray *hostp = [host componentsSeparatedByString:@"."];
			for (int i = 1; i < [hostp count]; i++) {
				NSString *wc = [[hostp subarrayWithRange:NSMakeRange(i, [hostp count] - i)] componentsJoinedByString:@"."];
				
				if ((blocker = [[[self class] targets] objectForKey:wc]) != nil) {
					break;
				}
			}
		}
	}
	
	if (blocker) {
		[[self class] cacheBlockedURL:url withRule:blocker];
	}
	
	return blocker;
}

+ (BOOL)shouldBlockURL:(NSURL *)url
{
	return ([self blockRuleForURL:url] != nil);
}

+ (BOOL)shouldBlockURL:(NSURL *)url fromMainDocumentURL:(NSURL *)mainUrl
{
	NSString *blocker = [self blockRuleForURL:url];
	if (blocker != nil && mainUrl != nil) {
		/* if this same rule would have blocked our main URL, allow it since the user is probably viewing this site and this isn't a sneaky tracker */
		if ([blocker isEqualToString:[self blockRuleForURL:mainUrl]]) {
			return NO;
		}
		
#ifdef TRACE_URL_BLOCKER
		NSLog(@"[URLBlocker] blocking %@ (via %@) (%@)", url, mainUrl, blocker);
#endif
		
		return YES;
	}
	
	return NO;
}

@end
