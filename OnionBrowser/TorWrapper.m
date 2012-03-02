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
    /*
     NSFileManager *filemgr;
     NSArray *dirPaths;
     dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, 
     NSUserDomainMask, YES);
     
     NSString *docsDir;
     NSString *torDir;
     NSString *tmpDir = NSTemporaryDirectory();
     
     docsDir = [dirPaths objectAtIndex:0];
     torDir = [docsDir stringByAppendingPathComponent:@"tor"];
     
     NSLog(@"%@", docsDir);
     NSLog(@"%@", torDir);
     
     NSDictionary *fileperms = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInteger:0x777]
     forKey:NSFilePosixPermissions];
     
     if ([filemgr isWritableFileAtPath:docsDir] == YES) {
     NSLog(@"is writable");
     } else {
     NSLog(@"NOT writable");
     }
     if ([filemgr setAttributes:fileperms ofItemAtPath:docsDir error:nil] == NO) {
     NSLog(@"docsdir perms?");
     }
     NSDictionary *f = [filemgr attributesOfItemAtPath:docsDir error:nil];
     NSLog(@"%@", f);
     
     if ([filemgr createDirectoryAtPath:torDir withIntermediateDirectories:YES attributes:nil error: NULL] == NO)
     {
     NSLog (@"failed to create tor dir");
     }
     if ([filemgr setAttributes:fileperms ofItemAtPath:torDir error:nil] == NO) {
     NSLog(@"torDir perms?");
     }
     
     NSArray *filelist;
     int count;
     int i;
     
     NSLog(@"%@", torDir);
     filemgr =[NSFileManager defaultManager];
     filelist = [filemgr contentsOfDirectoryAtPath:torDir error:NULL];
     count = [filelist count];
     
     for (i = 0; i < count; i++)
     NSLog(@"%@", [filelist objectAtIndex: i]);
     
     NSString *base_torrc = [[NSBundle mainBundle] pathForResource:@"torrc" ofType:nil];
     NSString *user_torrc = [torDir stringByAppendingPathComponent:@"torrc"];
     
     filemgr = [NSFileManager defaultManager];
     
     if ([filemgr removeItemAtPath: user_torrc error: NULL]  == YES) {
     }
     
     if ([filemgr fileExistsAtPath: user_torrc ] == YES) {
     //NSLog (@"user torrc exists");
     } else {
     NSLog (@"creating user torrc from default");
     if ([filemgr copyItemAtPath: base_torrc toPath: user_torrc error: NULL]  == YES) {
     //NSLog (@"Copy successful");
     } else {
     NSLog (@"Copy failed");
     }
     }
     
     char *arg_0 = "tor";
     char *arg_1 = "DataDirectory";
     char *arg_2 = (char*)[[torDir dataUsingEncoding:NSUTF8StringEncoding] bytes];
     char *arg_3 = "-f";
     char *arg_4 = (char*)[[user_torrc dataUsingEncoding:NSUTF8StringEncoding] bytes];
     */
    
    self.status = TOR_IS_RUNNING;
    
    NSLog(@"Starting tor...");
    
    NSString *tmpDir = NSTemporaryDirectory();
    NSString *base_torrc = [[NSBundle mainBundle] pathForResource:@"torrc" ofType:nil];
    NSString *geoip = [[NSBundle mainBundle] pathForResource:@"geoip" ofType:nil];
    
    /*
    NSFileManager *filemgr;
    NSArray *filelist;
    int count;
    int i;
    NSLog(@"%@", tmpDir);
    filemgr =[NSFileManager defaultManager];
    filelist = [filemgr contentsOfDirectoryAtPath:tmpDir error:NULL];
    count = [filelist count];
    
    for (i = 0; i < count; i++)
        NSLog(@"%@", [filelist objectAtIndex: i]);
    */
    
    /**************/
    
    char *arg_0 = "tor";
    char *arg_1 = "DataDirectory";
    char *arg_2 = (char *)[tmpDir cStringUsingEncoding:NSUTF8StringEncoding];
    char *arg_3 = "GeoIPFile";
    char *arg_4 = (char *)[geoip cStringUsingEncoding:NSUTF8StringEncoding];
    char *arg_5 = "-f";
    char *arg_6 = (char *)[base_torrc cStringUsingEncoding:NSUTF8StringEncoding];
    
    char* argv[] = {arg_0, arg_1, arg_2, arg_3, arg_4, arg_5, arg_6, NULL};
    tor_main(7, argv);
}
-(void)halt_tor {
    if (self.status == TOR_IS_RUNNING) {
        #ifdef DEBUG
            NSLog(@"Halting tor...");
        #endif
        self.status = TOR_IS_STOPPING;
        [self cancel];
        raise(SIGINT);
        self.status = TOR_IS_STOPPED;
    }
}
-(void)kill_tor {
    if (self.status == TOR_IS_RUNNING) {
        #ifdef DEBUG
            NSLog(@"Halting tor...");
        #endif
        self.status = TOR_IS_STOPPING;
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
    
    #ifdef USE_DMALLOC
        dmalloc_log_stats();
    #endif
    tor_free_all(1);
    crypto_global_cleanup();
    
    #ifdef USE_DMALLOC
        dmalloc_log_unfreed();
        dmalloc_shutdown();
    #endif
}


@end
