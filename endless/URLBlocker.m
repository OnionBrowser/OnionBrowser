#import "URLBlocker.h"

@implementation URLBlocker

static NSDictionary *_targets;
static NSCache *ruleCache;

#define RULE_CACHE_SIZE 20

+ (NSDictionary *)targets
{
	if (_targets == nil) {
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *path = [[NSBundle mainBundle] pathForResource:@"urlblocker_targets" ofType:@"plist"];
		if (![fm fileExistsAtPath:path]) {
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

+ (void)cacheBlockedURL:(NSURL *)url
{
	if (!ruleCache) {
		ruleCache = [[NSCache alloc] init];
		[ruleCache setCountLimit:RULE_CACHE_SIZE];
	}
	
#ifdef TRACE_URL_BLOCKER
	NSLog(@"[URLBlocker] cache miss, blocking %@", url);
#endif
	
	[ruleCache setObject:@TRUE forKey:url];
}

+ (BOOL)shouldBlockURL:(NSURL *)url
{
	if (ruleCache && [ruleCache objectForKey:url]) {
#ifdef TRACE_URL_BLOCKER
		NSLog(@"[URLBlocker] cache hit, blocking %@", url);
#endif
		return TRUE;
	}
	
	BOOL block = NO;

	NSString *host = [[url host] lowercaseString];
	
	if ([[[self class] targets] objectForKey:host])
		block = YES;

	if (!block) {
		/* now for x.y.z.example.com, try *.y.z.example.com, *.z.example.com, *.example.com, etc. */
		/* TODO: should we skip the last component for obviously non-matching things like "*.com", "*.net"? */
		NSArray *hostp = [host componentsSeparatedByString:@"."];
		for (int i = 1; i < [hostp count]; i++) {
			NSString *wc = [[hostp subarrayWithRange:NSMakeRange(i, [hostp count] - i)] componentsJoinedByString:@"."];
			
			if ([[[self class] targets] objectForKey:wc]) {
				block = YES;
				
#ifdef TRACE_URL_BLOCKER
				NSLog(@"[URLBlocker] found block for component %@ in %@", wc, host);
#endif
				break;
			}
		}
	}
	
	if (block)
		[[self class] cacheBlockedURL:url];
	
	return block;
}

@end
