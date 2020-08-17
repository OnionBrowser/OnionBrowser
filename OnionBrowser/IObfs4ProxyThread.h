/*
 * Onion Browser
 * Copyright (c) 2012-2018, Tigas Ventures, LLC (Mike Tigas)
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSUInteger const kObfs4SocksPort;
FOUNDATION_EXPORT NSUInteger const kMeekSocksPort;
FOUNDATION_EXPORT NSUInteger const kObfs2SocksPort;
FOUNDATION_EXPORT NSUInteger const kObfs3SocksPort;
FOUNDATION_EXPORT NSUInteger const kScramblesuitSocksPort;


@interface IObfs4ProxyThread : NSThread

@property (readonly) NSUInteger obfs4SocksPort;
@property (readonly) NSUInteger meekSocksPort;
@property (readonly) NSUInteger obfs2SocksPort;
@property (readonly) NSUInteger obfs3SocksPort;
@property (readonly) NSUInteger scramblesuitSocksPort;

@end
