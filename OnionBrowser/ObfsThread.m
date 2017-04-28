//
//  ObfsThread.h
//  iObfs
//  Copyright © 2016 Mike Tigas. All rights reserved. Available under
//  BSD license; see https://github.com/mtigas/iObfs/blob/master/LICENSE
//

#import "ObfsThread.h"
#include <Iobfs4proxy/Iobfs4proxy.h>

@implementation ObfsThread

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
