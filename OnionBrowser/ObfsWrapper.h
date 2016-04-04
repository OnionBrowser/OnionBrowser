//
//  ObfsWrapper.h
//  iObfs
//
//  Created by Mike Tigas on 4/3/16.
//  Copyright © 2016 Mike Tigas. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ObfsWrapper : NSThread

@property (nonatomic) unsigned int obfsSocksPort;
@property (nonatomic) unsigned int meekSocksPort;


@end
