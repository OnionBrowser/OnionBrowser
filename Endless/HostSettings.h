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

#import <Foundation/Foundation.h>

#define HOST_SETTINGS_KEY_HOST @"host"
#define HOST_SETTINGS_HOST_DEFAULT @"__default__"
#define HOST_SETTINGS_HOST_DEFAULT_LABEL @"Default Host"

#define HOST_SETTINGS_KEY_TLS @"min_tls"
#define HOST_SETTINGS_TLS_12 @"1.2"
#define HOST_SETTINGS_TLS_AUTO @"1.1"
#define HOST_SETTINGS_TLS_OR_SSL_AUTO @"auto"

#define HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS @"block_into_local_nets"

#define HOST_SETTINGS_KEY_WHITELIST_COOKIES @"whitelist_cookies"

#define HOST_SETTINGS_KEY_ALLOW_MIXED_MODE @"allow_mixed_mode"

@interface HostSettings : NSObject

@property (strong) NSMutableDictionary *dict;

+ (void)persist;

+ (HostSettings *)defaultHostSettings;
+ (HostSettings *)settingsForHost:(NSString *)host;
+ (HostSettings *)settingsOrDefaultsForHost:(NSString *)host;
+ (BOOL)removeSettingsForHost:(NSString *)host;
#ifdef DEBUG
+ (void)overrideHosts:(NSMutableDictionary *)hosts;
#endif

+ (NSArray *)sortedHosts;

- (HostSettings *)initForHost:(NSString *)host withDict:(NSDictionary *)vals;
- (void)save;
- (BOOL)isDefault;

- (NSString *)hostname;
- (void)setHostname:(NSString *)hostname;

- (NSString *)TLSVersion;
- (void)setTLSVersion:(NSString *)version;

- (BOOL)blockIntoLocalNets;
- (void)setBlockIntoLocalNets:(BOOL)value;

- (BOOL)whitelistCookies;
- (void)setWhitelistCookies:(BOOL)value;

- (BOOL)allowMixedModeContent;
- (void)setAllowMixedModeContent:(BOOL)value;

@end
