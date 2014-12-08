#import "HTTPSEverywhere.h"

@implementation HTTPSEverywhere

static NSDictionary *_rules;
static NSDictionary *_targets;

static NSCache *ruleCache;

#define RULE_CACHE_SIZE 20

+ (NSDictionary *)rules {
	if (_rules == nil) {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *path = [[NSBundle mainBundle] pathForResource:@"https-everywhere_rules" ofType:@"plist"];
		if (![fm fileExistsAtPath:path]) {
			NSLog(@"[HTTPSEverywhere] no rule plist at %@", path);
			abort();
		}
		
		_rules = [NSDictionary dictionaryWithContentsOfFile:path];
		
#ifdef TRACE_HTTPS_EVERYWHERE
		NSLog(@"[HTTPSEverywhere] locked and loaded with %lu rules", [_rules count]);
#endif
	}
	
	return _rules;
}

+ (NSDictionary *)targets {
	if (_targets == nil) {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *path = [[NSBundle mainBundle] pathForResource:@"https-everywhere_targets" ofType:@"plist"];
		if (![fm fileExistsAtPath:path]) {
			NSLog(@"[HTTPSEverywhere] no target plist at %@", path);
			abort();
		}
		
		_targets = [NSDictionary dictionaryWithContentsOfFile:path];
		
#ifdef TRACE_HTTPS_EVERYWHERE
		NSLog(@"[HTTPSEverywhere] locked and loaded with %lu target domains", [_targets count]);
#endif
	}
	
	return _targets;
}

+ (void)cacheRule:(HTTPSEverywhereRule *)rule forName:(NSString *)name {
	if (!ruleCache) {
		ruleCache = [[NSCache alloc] init];
		[ruleCache setCountLimit:RULE_CACHE_SIZE];
	}
	
#ifdef TRACE_HTTPS_EVERYWHERE
	NSLog(@"[HTTPSEverywhere] cache miss for %@", name);
#endif

	[ruleCache setObject:rule forKey:name];
}

+ (HTTPSEverywhereRule *)cachedRuleForName:(NSString *)name {
	HTTPSEverywhereRule *r;
	
	if (ruleCache) {
		if ((r = [ruleCache objectForKey:name]) != nil) {
#ifdef TRACE_HTTPS_EVERYWHERE
			NSLog(@"[HTTPSEverywhere] cache hit for %@", name);
#endif
			return r;
		}
	}
	
	r = [[HTTPSEverywhereRule alloc] initWithDictionary:[[[self class] rules] objectForKey:name]];
	[[self class] cacheRule:r forName:name];
	
	return r;
}

+ (NSArray *)potentiallyApplicableRulesFor:(NSString *)host {
	NSMutableDictionary *rs = [[NSMutableDictionary alloc] initWithCapacity:2];
	
	host = [host lowercaseString];

	NSString *targetName = [[[self class] targets] objectForKey:host];
	if (targetName != nil)
		[rs setValue:[[self class] cachedRuleForName:targetName] forKey:targetName];
	
	/* now for x.y.z.example.com, try *.y.z.example.com, *.z.example.com, *.example.com, etc. */
	/* TODO: should we skip the last component for obviously non-matching things like "*.com", "*.net"? */
	NSArray *hostp = [host componentsSeparatedByString:@"."];
	for (int i = 1; i < [hostp count]; i++) {
		NSString *wc = [[hostp subarrayWithRange:NSMakeRange(i, [hostp count] - i)] componentsJoinedByString:@"."];
		
		NSString *targetName = [[[self class] targets] objectForKey:wc];
		if (targetName != nil) {
#ifdef TRACE_HTTPS_EVERYWHERE
			NSLog(@"[HTTPSEverywhere] found ruleset %@ for component %@ in %@", targetName, wc, host);
#endif
			if (![rs objectForKey:targetName])
				[rs setValue:[[self class] cachedRuleForName:targetName] forKey:targetName];
		}
	}
	
	return [rs allValues];
}

+ (NSURL *)rewrittenURI:(NSURL *)URL {
	NSArray *rs = [[self class] potentiallyApplicableRulesFor:[URL host]];

	if (rs == nil || [rs count] == 0)
		return URL;
	
#ifdef TRACE_HTTPS_EVERYWHERE
	NSLog(@"[HTTPSEverywhere] have %lu applicable ruleset(s) for %@", [rs count], [URL absoluteString]);
#endif
	
	for (HTTPSEverywhereRule *rule in rs) {
		NSURL *rurl = [rule apply:URL];
		if (rurl != nil)
			return rurl;
	}
	
	return URL;
}

@end
