/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "URLBlocker.h"

@implementation URLBlocker

static NSDictionary *_targets;
static NSMutableDictionary *_disabledTargets;
static NSCache *ruleCache;

#define RULE_CACHE_SIZE 20

+ (NSString *)disabledTargetsPath
{
	NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	return [path stringByAppendingPathComponent:@"url_blocker_disabled.plist"];
}

+ (NSDictionary *)targets
{
	NSError *error;
	
	if (_targets == nil) {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"urlblocker" ofType:@"json"];
		if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
			NSLog(@"[URLBlocker] no target plist at %@", path);
			abort();
		}
		
		NSInputStream *input = [[NSInputStream alloc] initWithFileAtPath:path];
		if (input != nil) {
			[input open];
			
			NSDictionary *blockers = [NSJSONSerialization JSONObjectWithStream:input options:kNilOptions error:&error];
			if (error != nil)
				NSLog(@"[URLBlocker] couldn't read %@: %@", path, error);
			[input close];
			
			/* convert from { "desc" => [ "host1", "host2" ] } to { "host1" => "desc", "host2" => "desc" } */
			NSMutableDictionary *ttargets = [[NSMutableDictionary alloc] init];
			for (NSString *key in [blockers allKeys]) {
				NSArray *doms = [blockers objectForKey:key];
				for (NSString *dom in doms)
					[ttargets setObject:key forKey:dom];
			}
			
			_targets = [NSDictionary dictionaryWithDictionary:ttargets];
		}
		
		if (!_targets || ![_targets count]) {
			NSLog(@"[URLBlocker] couldn't read %@", path);
			_targets = @{};
			return _targets;
		}
		
#ifdef TRACE_URL_BLOCKER
		NSLog(@"[URLBlocker] locked and loaded with %lu target domains", [_targets count]);
#endif
	}
	
	return _targets;
}

+ (NSMutableDictionary *)disabledTargets
{
	if (_disabledTargets == nil) {
		NSString *path = [[self class] disabledTargetsPath];
		if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
			_disabledTargets = [NSMutableDictionary dictionaryWithContentsOfFile:path];
			
#ifdef TRACE_HTTPS_EVERYWHERE
			NSLog(@"[URLBlocker] loaded %lu disabled targets", [_disabledTargets count]);
#endif
		}
		else {
			_disabledTargets = [[NSMutableDictionary alloc] init];
		}
	}
	
	return _disabledTargets;
}

+ (void)saveDisabledTargets
{
	[_disabledTargets writeToFile:[[self class] disabledTargetsPath] atomically:YES];
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
		
		if ([[[self class] targets] objectForKey:host])
			blocker = host;
		else {
			/* now for x.y.z.example.com, try *.y.z.example.com, *.z.example.com, *.example.com, etc. */
			/* TODO: should we skip the last component for obviously non-matching things like "*.com", "*.net"? */
			NSArray *hostp = [host componentsSeparatedByString:@"."];
			for (int i = 1; i < [hostp count]; i++) {
				NSString *wc = [[hostp subarrayWithRange:NSMakeRange(i, [hostp count] - i)] componentsJoinedByString:@"."];
				
				if ([[[self class] targets] objectForKey:wc]) {
					blocker = wc;
					break;
				}
			}
		}
	}
	
	if (blocker && [[URLBlocker disabledTargets] objectForKey:blocker] != nil)
		return nil;
	
	if (blocker)
		[[self class] cacheBlockedURL:url withRule:blocker];
	
	return blocker;
}

+ (BOOL)shouldBlockURL:(NSURL *)url
{
	return ([self blockRuleForURL:url] != nil);
}

+ (NSString *)blockingTargetForURL:(NSURL *)url fromMainDocumentURL:(NSURL *)mainUrl
{
	NSString *blocker = [self blockRuleForURL:url];
	if (blocker != nil && mainUrl != nil) {
		/* if this same rule would have blocked our main URL, allow it since the user is probably viewing this site and this isn't a sneaky tracker */
		if ([blocker isEqualToString:[self blockRuleForURL:mainUrl]]) {
			return nil;
		}
		
#ifdef TRACE_URL_BLOCKER
		NSLog(@"[URLBlocker] blocking %@ (via %@) (%@)", url, mainUrl, blocker);
#endif
		
		return blocker;
	}
	
	return nil;
}

+ (void)enableTargetByHost:(NSString *)target
{
	[[[self class] disabledTargets] removeObjectForKey:target];
	[[self class] saveDisabledTargets];
}

+ (void)disableTargetByHost:(NSString *)target withReason:(NSString *)reason
{
	[[[self class] disabledTargets] setObject:reason forKey:target];
	[[self class] saveDisabledTargets];
}

@end
