/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AppDelegate.h"
#import "HostSettings.h"

@implementation HostSettings

NSMutableDictionary *_hosts;

+ (NSString *)hostSettingsPath
{
	NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
	return [path stringByAppendingPathComponent:@"host_settings.plist"];
}

+ (NSMutableDictionary *)hosts
{
	if (!_hosts) {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		if ([fileManager fileExistsAtPath:[self hostSettingsPath]]) {
			NSDictionary *td = [NSMutableDictionary dictionaryWithContentsOfFile:[self hostSettingsPath]];
			
			_hosts = [[NSMutableDictionary alloc] initWithCapacity:[td count]];
			
			for (NSString *k in [td allKeys])
				[_hosts setObject:[[HostSettings alloc] initForHost:k withDict:[td objectForKey:k]] forKey:k];
		}
		else
			_hosts = [[NSMutableDictionary alloc] initWithCapacity:20];
		
		/* ensure default host exists */
		if (![_hosts objectForKey:HOST_SETTINGS_KEY_HOST])
			(void)[[HostSettings alloc] initForHost:HOST_SETTINGS_HOST_DEFAULT withDict:nil];
	}
	
	return _hosts;
}

+ (void)persist
{
	NSMutableDictionary *td = [[NSMutableDictionary alloc] initWithCapacity:[[self hosts] count]];
	for (NSString *k in [[self hosts] allKeys])
		[td setObject:[[[self hosts] objectForKey:k] dict] forKey:k];

	[td writeToFile:[self hostSettingsPath] atomically:YES];
}

+ (HostSettings *)settingsForHost:(NSString *)host
{
	return [[self hosts] objectForKey:host];
}

+ (HostSettings *)settingsOrDefaultsForHost:(NSString *)host
{
	HostSettings *hs = [self settingsForHost:host];
	if (!hs) {
		/* for a host of x.y.z.example.com, try y.z.example.com, z.example.com, example.com, etc. */
		NSArray *hostp = [host componentsSeparatedByString:@"."];
		for (int i = 1; i < [hostp count]; i++) {
			NSString *wc = [[hostp subarrayWithRange:NSMakeRange(i, [hostp count] - i)] componentsJoinedByString:@"."];
			
			if ((hs = [HostSettings settingsForHost:wc])) {
#ifdef TRACE_HOST_SETTINGS
				NSLog(@"[HostSettings] found entry for component %@ in %@", wc, host);
#endif
				break;
			}
		}
	}
	
	if (!hs) {
#ifdef TRACE_HOST_SETTINGS
		NSLog(@"[HostSettings] using default settings for %@", host);
#endif
		hs = [self defaultHostSettings];
	}

	return hs;
}

+ (BOOL)removeSettingsForHost:(NSString *)host
{
	HostSettings *h = [self settingsForHost:host];
	if (h && ![h isDefault]) {
		[[self hosts] removeObjectForKey:host];
		return YES;
	}
	
	return NO;
}

+ (HostSettings *)defaultHostSettings
{
	return [self settingsForHost:HOST_SETTINGS_HOST_DEFAULT];
}

#ifdef DEBUG
/* just for testing */
+ (void)overrideHosts:(NSMutableDictionary *)hosts;
{
	_hosts = hosts;
}
#endif

+ (NSArray *)sortedHosts
{
	NSMutableArray *sorted = [[NSMutableArray alloc] initWithArray:[[self hosts] allKeys]];
	[sorted removeObject:HOST_SETTINGS_HOST_DEFAULT];
	[sorted sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
	[sorted insertObject:HOST_SETTINGS_HOST_DEFAULT atIndex:0];
	
	return [[NSArray alloc] initWithArray:sorted];
}

- (HostSettings *)initForHost:(NSString *)host withDict:(NSDictionary *)dict
{
	self = [super init];
	
	host = [host lowercaseString];

	if (dict)
		_dict = [[NSMutableDictionary alloc] initWithDictionary:dict];
	else
		_dict = [[NSMutableDictionary alloc] initWithCapacity:10];
	
	[_dict setObject:host forKey:HOST_SETTINGS_KEY_HOST];

	/* ensure all defaults are set */
	NSDictionary *defs = @{
			       HOST_SETTINGS_KEY_TLS: HOST_SETTINGS_TLS_AUTO,
			       HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS: @YES,
			       HOST_SETTINGS_KEY_WHITELIST_COOKIES: @NO,
			       HOST_SETTINGS_KEY_ALLOW_MIXED_MODE: @NO,
			       };
	
	for (NSString *k in [defs allKeys]) {
		NSObject *v = [_dict objectForKey:k];
		if (v != nil) {
			if ([v isKindOfClass:[NSString class]] && ![(NSString *)v isEqualToString:@""])
				continue;
			else if ([v isKindOfClass:[NSNumber class]])
				continue;
		}
		
		[_dict setObject:[defs objectForKey:k] forKey:k];
	}
	
	return self;
}

- (void)save
{
	[[HostSettings hosts] setObject:self forKey:[[self dict] objectForKey:HOST_SETTINGS_KEY_HOST]];
	[HostSettings persist];
}

- (BOOL)isDefault
{
	return ([[[self dict] objectForKey:HOST_SETTINGS_KEY_HOST] isEqualToString:HOST_SETTINGS_HOST_DEFAULT]);
}

- (NSString *)hostname
{
	if ([self isDefault])
		return HOST_SETTINGS_HOST_DEFAULT_LABEL;
	else
		return [[self dict] objectForKey:HOST_SETTINGS_KEY_HOST];
}

- (void)setHostname:(NSString *)hostname
{
	if ([self isDefault] || !hostname || [hostname isEqualToString:@""])
		return;
	
	hostname = [hostname lowercaseString];
	
	[[HostSettings hosts] removeObjectForKey:[[self dict] objectForKey:HOST_SETTINGS_KEY_HOST]];
	[[self dict] setObject:hostname forKey:HOST_SETTINGS_KEY_HOST];
	[[HostSettings hosts] setObject:self forKey:hostname];
}

- (NSString *)TLSVersion
{
	return [[self dict] objectForKey:HOST_SETTINGS_KEY_TLS];
}
- (void)setTLSVersion:(NSString *)minVersion
{
	if (!([minVersion isEqualToString:HOST_SETTINGS_TLS_12] || [minVersion isEqualToString:HOST_SETTINGS_TLS_AUTO] ||
	[minVersion isEqualToString:HOST_SETTINGS_TLS_OR_SSL_AUTO])) {
		NSLog(@"invalid TLS version: %@", minVersion);
		return;
	}
	
	[[self dict] setObject:minVersion forKey:HOST_SETTINGS_KEY_TLS];
}

- (BOOL)blockIntoLocalNets
{
	return [[[self dict] objectForKey:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS] boolValue];
}
- (void)setBlockIntoLocalNets:(BOOL)value
{
	[[self dict] setObject:[NSNumber numberWithBool:value] forKey:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS];
}

- (BOOL)whitelistCookies
{
	return [[[self dict] objectForKey:HOST_SETTINGS_KEY_WHITELIST_COOKIES] boolValue];
}
- (void)setWhitelistCookies:(BOOL)value
{
	[[self dict] setObject:[NSNumber numberWithBool:value] forKey:HOST_SETTINGS_KEY_WHITELIST_COOKIES];
}

- (BOOL)allowMixedModeContent
{
	return [[[self dict] objectForKey:HOST_SETTINGS_KEY_ALLOW_MIXED_MODE] boolValue];
}
- (void)setAllowMixedModeContent:(BOOL)value
{
	[[self dict] setObject:[NSNumber numberWithBool:value] forKey:HOST_SETTINGS_KEY_ALLOW_MIXED_MODE];
}

@end