/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "HTTPSEverywhere.h"
#import "HTTPSEverywhereRule.h"

@implementation HTTPSEverywhereRule

/* typical ruleset imported from XML rule:
 
    ruleset = {
        exclusion = {
            pattern = "^http://(help|meme)\\.duckduckgo\\.com/";
        };
        name = DuckDuckGo;
        rule = (
            {
                from = "^http://duckduckgo\\.com/";
                to = "https://duckduckgo.com/";
            },
            {
                from = "^http://([^/:@\\.]+)\\.duckduckgo\\.com/";
                to = "https://$1.duckduckgo.com/";
            },
        );
        securecookie = {
            host = "^duck\\.co$";
            name = ".*";
        };
        target = (
            {
                host = "duckduckgo.com";
            },
            {
                host = "*.duckduckgo.com";
            },
        );
    };
*/

- (id)initWithDictionary:(NSDictionary *)dict
{
	NSError *error;
	NSObject *t;
	
	NSDictionary *ruleset = [dict objectForKey:@"ruleset"];
	if (ruleset == nil) {
		NSLog(@"[HTTPSEverywhere] ruleset dict not found in %@", dict);
		return nil;
	}
	
	self = [super init];
	if (!self)
		return nil;
	
	self.name = (NSString *)[ruleset objectForKey:@"name"];
	
	NSString *doff = [ruleset objectForKey:@"default_off"];
	if (doff != nil && ![doff isEqualToString:@""]) {
		self.on_by_default = NO;
		self.notes = doff;
	} else {
		self.on_by_default = YES;
	}

	self.platform = (NSString *)[ruleset objectForKey:@"platform"];
	/* TODO: do something useful with platform to disable rules */

	/* exclusions */
	if ((t = [ruleset objectForKey:@"exclusion"]) != nil) {
		if (![t isKindOfClass:[NSArray class]])
			t = [[NSArray alloc] initWithObjects:t, nil];
		
		NSMutableArray *excs = [[NSMutableArray alloc] initWithCapacity:2];
		
		for (NSDictionary *excd in (NSArray *)t) {
			NSString *pattern = [excd valueForKey:@"pattern"];
			
			NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:NSRegularExpressionCaseInsensitive error:&error];
			if (error != nil) {
				NSLog(@"[HTTPSEverywhere] error compiling regex %@: %@", pattern, error);
				continue;
			}
			
			[excs addObject:regex];
		}
		
		self.exclusions = excs;
	}
	
	/* actual url mappings, dictionary of input url regex -> good url */
	if ((t = [ruleset objectForKey:@"rule"]) != nil) {
		if (![t isKindOfClass:[NSArray class]])
			t = [[NSArray alloc] initWithObjects:t, nil];
		
		NSMutableDictionary *rulesd = [[NSMutableDictionary alloc] initWithCapacity:2];
		
		for (NSDictionary *ruled in (NSArray *)t) {
			NSString *from = [ruled valueForKey:@"from"];
			NSString *to = [ruled valueForKey:@"to"];
			
			NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:from options:NSRegularExpressionCaseInsensitive error:&error];
			if (error != nil) {
				NSLog(@"[HTTPSEverywhere] error compiling regex %@: %@", from, error);
				continue;
			}

			[rulesd setObject:to forKey:regex];
		}
		
		self.rules = rulesd;
	}
	
	/* securecookies, dictionary of host regex -> cookie name regex */
	if ((t = [ruleset objectForKey:@"securecookie"]) != nil) {
		if (![t isKindOfClass:[NSArray class]])
			t = [[NSArray alloc] initWithObjects:t, nil];
		
		NSMutableDictionary *scooksd = [[NSMutableDictionary alloc] initWithCapacity:2];
		
		for (NSDictionary *scookd in (NSArray *)t) {
			NSString *host = [scookd valueForKey:@"host"];
			NSString *cname = [scookd valueForKey:@"name"];
			
			NSRegularExpression *hostreg = [NSRegularExpression regularExpressionWithPattern:host options:NSRegularExpressionCaseInsensitive error:&error];
			if (error != nil) {
				NSLog(@"[HTTPSEverywhere] error compiling regex %@: %@", host, error);
				continue;
			}
			
			NSRegularExpression *namereg = [NSRegularExpression regularExpressionWithPattern:cname options:NSRegularExpressionCaseInsensitive error:&error];
			if (error != nil) {
				NSLog(@"[HTTPSEverywhere] error compiling regex %@: %@", cname, error);
				continue;
			}
			
			[scooksd setObject:namereg forKey:hostreg];
		}
		
		self.secureCookies = scooksd;
	}
	
	return self;
}

/* return nil if URL was not modified by this rule */
- (NSURL *)apply:(NSURL *)url
{
	NSString *absURL = [url absoluteString];
	NSArray *matches;

	for (NSRegularExpression *reg in (NSArray *)self.exclusions) {
		if ((matches = [reg matchesInString:absURL options:0 range:NSMakeRange(0, [absURL length])]) != nil && [matches count] > 0) {
#ifdef TRACE_HTTPS_EVERYWHERE
			NSLog(@"[HTTPSEverywhere] [%@] exclusion %@ matched %@", self.name, [reg pattern], absURL);
#endif
			return nil;
		}
	}
	
	for (NSRegularExpression *reg in (NSDictionary *)self.rules) {
		if ((matches = [reg matchesInString:absURL options:0 range:NSMakeRange(0, [absURL length])]) != nil && [matches count] > 0) {
			NSString *dest = [[self rules] objectForKey:reg];
			dest = [reg stringByReplacingMatchesInString:absURL options:0 range:NSMakeRange(0, [absURL length]) withTemplate:dest];
			
#ifdef TRACE_HTTPS_EVERYWHERE
			NSLog(@"[HTTPSEverywhere] [%@] rewrote %@ to %@", self.name, absURL, dest);
#endif
			
			/* JS implementation says first matching wins */
			return [NSURL URLWithString:dest];
		}
	}

	return nil;
}

@end
