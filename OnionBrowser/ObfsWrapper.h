// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>

@interface ObfsWrapper : NSThread

@property (nonatomic) unsigned int obfs4SocksPort;
@property (nonatomic) unsigned int meekSocksPort;
@property (nonatomic) unsigned int obfs2SocksPort;
@property (nonatomic) unsigned int obfs3SocksPort;
@property (nonatomic) unsigned int scramblesuitSocksPort;


@end
