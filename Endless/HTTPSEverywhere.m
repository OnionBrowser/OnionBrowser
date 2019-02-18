/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "HTTPSEverywhere.h"

@implementation HTTPSEverywhere

static NSDictionary *_rules;
static NSDictionary *_targets;
static NSMutableDictionary *_disabledRules;
static NSMutableDictionary *insecureRedirections;

static NSCache *ruleCache;

#define RULE_CACHE_SIZE 20

+ (NSString *)disabledRulesPath
{
	NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	return [path stringByAppendingPathComponent:@"https_everywhere_disabled.plist"];
}

+ (NSDictionary *)rules
{
	if (_rules == nil) {
		NSString *path = [[NSBundle mainBundle] pathForResource:@"https-everywhere_rules" ofType:@"plist"];
		if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
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

+ (NSMutableDictionary *)disabledRules
{
	if (_disabledRules == nil) {
		NSString *path = [[self class] disabledRulesPath];
		if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
			_disabledRules = [NSMutableDictionary dictionaryWithContentsOfFile:path];
		
#ifdef TRACE_HTTPS_EVERYWHERE
			NSLog(@"[HTTPSEverywhere] loaded %lu disabled rules", [_disabledRules count]);
#endif
		}
		else {
			_disabledRules = [[NSMutableDictionary alloc] init];
		}
	}
	
	return _disabledRules;
}

+ (void)saveDisabledRules
{
	[_disabledRules writeToFile:[[self class] disabledRulesPath] atomically:YES];
}

+ (NSDictionary *)targets
{
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

+ (void)cacheRule:(HTTPSEverywhereRule *)rule forName:(NSString *)name
{
	if (!ruleCache) {
		ruleCache = [[NSCache alloc] init];
		[ruleCache setCountLimit:RULE_CACHE_SIZE];
	}
	
#ifdef TRACE_HTTPS_EVERYWHERE
	NSLog(@"[HTTPSEverywhere] cache miss for %@", name);
#endif

	[ruleCache setObject:rule forKey:name];
}

+ (HTTPSEverywhereRule *)cachedRuleForName:(NSString *)name
{
	HTTPSEverywhereRule *r;
	
	if (ruleCache && (r = [ruleCache objectForKey:name]) != nil) {
#ifdef TRACE_HTTPS_EVERYWHERE
		NSLog(@"[HTTPSEverywhere] cache hit for %@", name);
#endif
		return r;
	}

	r = [[HTTPSEverywhereRule alloc] initWithDictionary:[[[self class] rules] objectForKey:name]];
	[[self class] cacheRule:r forName:name];
	
	return r;
}

+ (NSArray *)potentiallyApplicableRulesForHost:(NSString *)host
{
	NSMutableDictionary *rs = [[NSMutableDictionary alloc] initWithCapacity:2];
	
	host = [host lowercaseString];

	NSString *targetName = [[[self class] targets] objectForKey:host];
	if (targetName != nil)
		[rs setValue:[[self class] cachedRuleForName:targetName] forKey:targetName];
	
	/* now for x.y.z.example.com, try *.y.z.example.com, *.z.example.com, *.example.com, etc. */
	/* TODO: should we skip the last component for obviously non-matching things like "*.com", "*.net"? */
	NSArray *hostp = [host componentsSeparatedByString:@"."];
	for (int i = 1; i < [hostp count]; i++) {
		NSString *wc = [NSString stringWithFormat:@"*.%@", [[hostp subarrayWithRange:NSMakeRange(i, [hostp count] - i)] componentsJoinedByString:@"."]];
		
		NSString *targetName = [[[self class] targets] objectForKey:wc];
		if (targetName != nil) {
#ifdef TRACE_HTTPS_EVERYWHERE
			NSLog(@"[HTTPSEverywhere] found ruleset %@ for component %@ in %@", targetName, wc, host);
#endif

			[rs setValue:[[self class] cachedRuleForName:targetName] forKey:targetName];
		}
	}
	
	return [rs allValues];
}

+ (NSURL *)rewrittenURI:(NSURL *)URL withRules:(NSArray *)rules
{
	if (rules == nil || [rules count] == 0)
		rules = [[self class] potentiallyApplicableRulesForHost:[URL host]];

	if (rules == nil || [rules count] == 0)
		return URL;
	
#ifdef TRACE_HTTPS_EVERYWHERE
	NSLog(@"[HTTPSEverywhere] have %lu applicable ruleset(s) for %@", [rules count], [URL absoluteString]);
#endif
	
	for (HTTPSEverywhereRule *rule in rules) {
		if ([[HTTPSEverywhere disabledRules] valueForKey:[rule name]] != nil)
			continue;

		NSURL *rurl = [rule apply:URL];
		if (rurl != nil)
			return rurl;
	}
	
	return URL;
}

+ (BOOL)needsSecureCookieFromHost:(NSString *)fromHost forHost:(NSString *)forHost cookieName:(NSString *)cookie
{
	for (HTTPSEverywhereRule *rule in [[self class] potentiallyApplicableRulesForHost:fromHost]) {
		if ([[HTTPSEverywhere disabledRules] valueForKey:[rule name]] != nil)
			continue;
		
		for (NSRegularExpression *hostreg in [rule secureCookies]) {
			if ([hostreg matchesInString:forHost options:0 range:NSMakeRange(0, [forHost length])]) {
				NSRegularExpression *namereg = [[rule secureCookies] objectForKey:hostreg];
			
				if ([namereg matchesInString:cookie options:0 range:NSMakeRange(0, [cookie length])]) {
#ifdef TRACE_HTTPS_EVERYWHERE
					NSLog(@"[HTTPSEverywhere] enabled securecookie for %@ from %@ for %@", cookie, fromHost, forHost);
#endif
					return YES;
				}
			}
		}
	}
	
	return NO;
}

+ (void)noteInsecureRedirectionForURL:(NSURL *)URL toURL:(NSURL *)toURL
{
	if (insecureRedirections == nil) {
		insecureRedirections = [[NSMutableDictionary alloc] init];
	}
	
	NSNumber *count = [insecureRedirections objectForKey:URL];
	if (count != nil && [count intValue] != 0)
		count = [NSNumber numberWithInt:[count intValue] + 1];
	else
		count = [NSNumber numberWithInt:1];
	
	[insecureRedirections setObject:count forKey:URL];
	
	if ([count intValue] < 3) {
		return;
	}
	
	for (HTTPSEverywhereRule *rule in [[self class] potentiallyApplicableRulesForHost:[URL host]]) {
		if ([rule apply:URL] != nil || [rule apply:toURL] != nil) {
			NSLog(@"[HTTPSEverywhere] insecure redirection count %@ for %@, disabling rule %@", count, URL, [rule name]);
			[[self class] disableRuleByName:[rule name] withReason:@"Redirection loop"];
		}
	}
}

+ (BOOL)ruleNameIsDisabled:(NSString *)name
{
	return ([[[self class] disabledRules] objectForKey:name] != nil);
}

+ (void)enableRuleByName:(NSString *)name
{
	[[[self class] disabledRules] removeObjectForKey:name];
	[[self class] saveDisabledRules];
}

+ (void)disableRuleByName:(NSString *)name withReason:(NSString *)reason
{
	[[[self class] disabledRules] setObject:reason forKey:name];
	[[self class] saveDisabledRules];
}

@end
