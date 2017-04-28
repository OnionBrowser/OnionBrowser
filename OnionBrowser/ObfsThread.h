//
//  ObfsThread.h
//  iObfs
//  Copyright © 2016 Mike Tigas. All rights reserved. Available under
//  BSD license; see https://github.com/mtigas/iObfs/blob/master/LICENSE
//

#import <Foundation/Foundation.h>

@interface ObfsThread : NSThread

@property (nonatomic) unsigned int obfs4SocksPort;
@property (nonatomic) unsigned int meekSocksPort;
@property (nonatomic) unsigned int obfs2SocksPort;
@property (nonatomic) unsigned int obfs3SocksPort;
@property (nonatomic) unsigned int scramblesuitSocksPort;

@end
