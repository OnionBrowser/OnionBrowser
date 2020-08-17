/*
 * Onion Browser
 * Copyright (c) 2012-2018, Tigas Ventures, LLC (Mike Tigas)
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import "IObfs4ProxyThread.h"
#include <Iobfs4proxy/Iobfs4proxy.h>

NSUInteger const kObfs4SocksPort = 47351;
NSUInteger const kMeekSocksPort = 47352;
NSUInteger const kObfs2SocksPort = 47353;
NSUInteger const kObfs3SocksPort = 47354;
NSUInteger const kScramblesuitSocksPort = 47355;


@implementation IObfs4ProxyThread

- (NSUInteger)obfs4SocksPort
{
	return kObfs4SocksPort;
}

- (NSUInteger)meekSocksPort
{
	return kMeekSocksPort;
}

- (NSUInteger)obfs2SocksPort
{
	return kObfs2SocksPort;
}

- (NSUInteger)obfs3SocksPort
{
	return kObfs3SocksPort;
}

- (NSUInteger)scramblesuitSocksPort
{
	return kScramblesuitSocksPort;
}


-(void)main {
	GoIobfs4proxyMain();
}

@end
