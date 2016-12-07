// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <Foundation/Foundation.h>
#import "TorWrapper.h"
#import "ULINetSocket.h"

@interface TorController : NSObject

#define CONN_STATUS_NONE 0
#define CONN_STATUS_CONNECTED 1

@property (nonatomic) unsigned int controllerIsAuthenticated;
@property (nonatomic) Boolean didFirstConnect;
@property (nonatomic) unsigned int connectionStatus;

@property (nonatomic) TorWrapper *torThread;
@property (nonatomic) NSTimer *torCheckLoopTimer;
@property (nonatomic) NSTimer *torStatusTimeoutTimer;
@property (nonatomic) ULINetSocket	*mSocket;

@property (nonatomic) unsigned int torSocksPort;
@property (nonatomic) unsigned int torControlPort;


- (id)init;
- (void)startTor;
- (void)hupTor;

- (void)requestNewTorIdentity;

- (void)disableNetwork;
- (void)enableNetwork;

- (void)activateTorCheckLoop;
- (void)disableTorCheckLoop;
- (void)checkTor;
- (void)checkTorStatusTimeout;

- (void)getCircuitInfo;
//- (NSString *)getCircuitInfoResponse;

- (void)reachabilityChanged;
- (void)appDidEnterBackground;
- (void)appDidBecomeActive;

@end
