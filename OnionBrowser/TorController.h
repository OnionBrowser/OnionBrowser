//
//  TorController.h
//  OnionBrowser
//
//  Created by Mike Tigas on 9/5/12.
//
//

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

- (void)activateTorCheckLoop;
- (void)disableTorCheckLoop;
- (void)checkTor;
- (void)checkTorStatusTimeout;

- (void)reachabilityChanged;
- (void)appDidEnterBackground;
- (void)appDidBecomeActive;

@end
