/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

@interface ObfsThread : NSThread

@property (nonatomic) unsigned int obfs4SocksPort;
@property (nonatomic) unsigned int meekSocksPort;
@property (nonatomic) unsigned int obfs2SocksPort;
@property (nonatomic) unsigned int obfs3SocksPort;
@property (nonatomic) unsigned int scramblesuitSocksPort;

@end
