//
//  TorWrapper.h
//  wut
//
//  Created by Mike Tigas on 2/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Tor/Tor.h>

@interface TorWrapper : NSObject
@property (nonatomic, retain) TORThread *tor;

//-(NSData *)readTorCookie;
-(void)start;
@end
