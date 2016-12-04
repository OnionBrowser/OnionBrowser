// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "ObfsWrapper.h"
#include <Iobfs4proxy/Iobfs4proxy.h>

@implementation ObfsWrapper

@synthesize
    obfs4SocksPort = _obfs4SocksPort,
    meekSocksPort = _meekSocksPort,
    obfs2SocksPort = _obfs2SocksPort,
    obfs3SocksPort = _obfs3SocksPort,
    scramblesuitSocksPort = _scramblesuitSocksPort
;

-(void)main {
    // TODO iObfs#1 eventually fix this so we use random ports
    //      and communicate that from obfs4proxy to iOS. These
    //      instance properties aren't being used yet.
    _obfs4SocksPort = 47351;
    _meekSocksPort = 47352;
    _obfs2SocksPort = 47353;
    _obfs3SocksPort = 47354;
    _scramblesuitSocksPort = 47355;

    GoIobfs4proxyMain();
}
@end
