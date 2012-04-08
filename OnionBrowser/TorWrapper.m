//
//  TorWrapper.m
//  wut
//
//  Created by Mike Tigas on 2/22/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TorWrapper.h"

@implementation TorWrapper

@synthesize status;

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
    char* argv[] = {arg_0, arg_1, arg_2, arg_3, arg_4, arg_5, arg_6, arg_7, arg_8, NULL};
    tor_main(9, argv);
    #endif
    #ifdef DEBUG
    char *arg_8 = "notice stderr";
    char *arg_9 = "DisableDebuggerAttachment";
    char *arg_10 = "0";
    char* argv[] = {arg_0, arg_1, arg_2, arg_3, arg_4, arg_5, arg_6, arg_7, arg_8, arg_9, arg_10, NULL};
    tor_main(11, argv);
    #endif
}

-(void)halt_tor {
    if (self.status == TOR_IS_RUNNING) {
        #ifdef DEBUG
            NSLog(@"TorWrapper: Halting tor (SIGINT)...");
        #endif
        self.status = TOR_IS_STOPPING;
        //fake_tor_cleanup();
        [self cancel];
        raise(SIGINT);
        self.status = TOR_IS_STOPPED;
    }
}
-(void)kill_tor {
    if (self.status == TOR_IS_RUNNING) {
        #ifdef DEBUG
            NSLog(@"TorWrapper: Halting tor (SIGTERM)...");
        #endif
        self.status = TOR_IS_STOPPING;
        //fake_tor_cleanup();
        [self cancel];
        raise(SIGTERM);
        self.status = TOR_IS_STOPPED;
    }
}

/** Do whatever cleanup is necessary before shutting Tor down. */
void fake_tor_cleanup(void) {
    #ifdef DEBUG
        NSLog(@"fake tor cleanup");
    #endif
    
    //#ifdef USE_DMALLOC
    //    dmalloc_log_stats();
    //#endif
    tor_free_all(1);
    crypto_global_cleanup();
    
    //#ifdef USE_DMALLOC
    //    dmalloc_log_unfreed();
    //    dmalloc_shutdown();
    //#endif
}


@end
