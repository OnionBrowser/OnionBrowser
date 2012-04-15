//
//  TorWrapper.m
//  wut
//
//  Created by Mike Tigas on 2/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TorWrapper.h"

@implementation TorWrapper

-(void)main {
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *base_torrc = [[NSBundle mainBundle] pathForResource:@"torrc" ofType:nil];
    NSString *geoip = [[NSBundle mainBundle] pathForResource:@"geoip" ofType:nil];

    /**************/
    
    char *arg_0 = "tor";

    // These options here (and not in torrc) since we don't know the temp dir
    // and data dir for this app until runtime.
    char *arg_1 = "DataDirectory";
    char *arg_2 = (char *)[tmpDir cStringUsingEncoding:NSUTF8StringEncoding];
    char *arg_3 = "GeoIPFile";
    char *arg_4 = (char *)[geoip cStringUsingEncoding:NSUTF8StringEncoding];
    char *arg_5 = "-f";
    char *arg_6 = (char *)[base_torrc cStringUsingEncoding:NSUTF8StringEncoding];
    
    // Set loglevel based on compilation option (loglevel "notice" for debug,
    // loglevel "warn" for release). Debug also will receive "DisableDebuggerAttachment"
    // torrc option (which allows GDB/LLDB to attach to the process).
    char *arg_7 = "Log";

    #ifndef DEBUG
    char *arg_8 = "warn stderr";
    #endif
    #ifdef DEBUG
    char *arg_8 = "notice stderr";
    #endif
    char* argv[] = {arg_0, arg_1, arg_2, arg_3, arg_4, arg_5, arg_6, arg_7, arg_8, NULL};
    tor_main(9, argv);
}

@end
