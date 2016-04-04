//
//  ObfsWrapper.m
//  iObfs
//
//  Created by Mike Tigas on 4/3/16.
//  Copyright © 2016 Mike Tigas. All rights reserved.
//

#import "ObfsWrapper.h"
#include <Iobfs4proxy/Iobfs4proxy.h>

@implementation ObfsWrapper

@synthesize
    obfsSocksPort = _obfsSocksPort,
    meekSocksPort = _meekSocksPort
;

-(void)main {
    /* TODO: We should re-enable the port randomization and find a way to
     *       communicate it back to the main app thread. */
    _obfsSocksPort = 47351;
    _meekSocksPort = 47352;

    GoIobfs4proxyMain();
}
@end
