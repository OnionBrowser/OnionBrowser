/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

#define HOST_SETTINGS_CHANGED @"host_settings_changed"

#define HOST_SETTINGS_DEFAULT @"__default"
#define HOST_SETTINGS_VALUE_YES @"1"
#define HOST_SETTINGS_VALUE_NO @"0"

#define HOST_SETTINGS_KEY_HOST @"host"
#define HOST_SETTINGS_HOST_DEFAULT_LABEL NSLocalizedString(@"Default Settings", nil)

#define HOST_SETTINGS_KEY_IGNORE_TLS_ERRORS @"ignore_tls_errors"

#define HOST_SETTINGS_KEY_TLS @"min_tls"
#define HOST_SETTINGS_TLS_12 @"1.2"
#define HOST_SETTINGS_TLS_AUTO @"1.1"

// #define HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS @"block_into_local_nets"

#define HOST_SETTINGS_KEY_WHITELIST_COOKIES @"whitelist_cookies"

#define HOST_SETTINGS_KEY_ALLOW_WEBRTC @"allow_webrtc"

#define HOST_SETTINGS_KEY_ALLOW_MIXED_MODE @"allow_mixed_mode"

#define HOST_SETTINGS_KEY_CSP @"content_policy"
#define HOST_SETTINGS_CSP_OPEN @"open"
#define HOST_SETTINGS_CSP_BLOCK_CONNECT @"block_connect"
#define HOST_SETTINGS_CSP_STRICT @"strict"

#define HOST_SETTINGS_KEY_USER_AGENT @"user_agent"

#define HOST_SETTINGS_KEY_UNIVERSAL_LINK_PROTECTION @"universal_link_protection"

@interface HostSettings : NSObject

@property (strong) NSMutableDictionary *dict;

+ (void)persist;

+ (NSDictionary *)defaults;
+ (HostSettings *)defaultHostSettings;
+ (HostSettings *)forHost:(NSString *)host;
+ (HostSettings *)settingsOrDefaultsForHost:(NSString *)host;
+ (BOOL)removeSettingsForHost:(NSString *)host;
#if DEBUG
+ (void)overrideHosts:(NSMutableDictionary *)hosts;
#endif
+ (NSArray *)sortedHosts;
+ (void)migrateFromBuild:(long)lastBuild toBuild:(long)thisBuild;

- (HostSettings *)initForHost:(NSString *)host withDict:(NSDictionary *)vals;
- (void)save;
- (BOOL)isDefault;

- (NSString *)setting:(NSString *)setting;
- (NSString *)settingOrDefault:(NSString *)setting;
- (BOOL)boolSettingOrDefault:(NSString *)setting;
- (void)setSetting:(NSString *)setting toValue:(NSString *)value;

- (NSString *)hostname;
- (void)setHostname:(NSString *)hostname;

@end
