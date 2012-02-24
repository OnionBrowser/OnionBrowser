//
//  AppDelegate.m
//  OnionBrowser
//
//  Copyright (c) 2012 Mike Tigas. All rights reserved.
//

#import "AppDelegate.h"
#include <Openssl/sha.h>

@implementation AppDelegate

@synthesize window = _window;

- (void)dealloc
{
    [_window release];
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    /* Test */
    // Test A
    unsigned char *inStrg = (unsigned char*)[@"" cStringUsingEncoding:NSASCIIStringEncoding];
	unsigned long lngth = 0;
    NSMutableString *outStrg = [NSMutableString string];

    // Test B
    NSString *stringB = @"The quick brown fox jumps over the lazy dog";
    unsigned char *inStrgB = (unsigned char*)[stringB cStringUsingEncoding:NSASCIIStringEncoding];
	unsigned long lngthB = [stringB length];
    NSMutableString *outStrgB = [NSMutableString string];
	
    // Initialize a sha256 object, a counter, and a result array.
    unsigned int i;
    SHA256_CTX sha256;
	unsigned char result[SHA256_DIGEST_LENGTH];
    
    // Process first test
    SHA256_Init(&sha256);
    SHA256_Update(&sha256, inStrg, lngth);
    SHA256_Final(result, &sha256);
    for(i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        [outStrg appendFormat:@"%02x", result[i]];
    }
    // Process second test
    SHA256_Init(&sha256);
    SHA256_Update(&sha256, inStrgB, lngthB);
    SHA256_Final(result, &sha256);
    for(i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        [outStrgB appendFormat:@"%02x", result[i]];
    }
    
    NSLog(@"Some SHA256 tests to make sure OpenSSL compiled in properly:");
    NSLog(@"'':");
    NSLog(@"\t%@", outStrg);
    NSLog(@"should be: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    NSLog(@"");
    NSLog(@"'test':");
    NSLog(@"\t%@", outStrgB);
    NSLog(@"should be: d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592");
    NSLog(@"");
    NSLog(@"View https://en.wikipedia.org/wiki/SHA-2 for more info");

    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
