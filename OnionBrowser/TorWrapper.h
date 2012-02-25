//
//  TorWrapper.h
//  wut
//
//  Created by Mike Tigas on 2/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "or/or.h"
#include "or/main.h"
#include <pthread.h>

#define TOR_IS_RUNNING 0
#define TOR_IS_STOPPING 1
#define TOR_IS_STOPPED 2


@interface TorWrapper : NSThread {
    NSUInteger status;
}

@property (atomic) NSUInteger status;

- (void)halt_tor;
- (void)kill_tor;

@end
