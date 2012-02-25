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

    // Test B
    NSString *stringB = @"The quick brown fox jumps over the lazy dog";
    unsigned char *inStrgB = (unsigned char*)[stringB cStringUsingEncoding:NSASCIIStringEncoding];
	unsigned long lngthB = [stringB length];
	
    // Initialize a sha2 object, a counter, and a result array.
    SHA256_CTX sha256;
	unsigned char result256[SHA256_DIGEST_LENGTH];
    SHA512_CTX sha512;
	unsigned char result512[SHA512_DIGEST_LENGTH];
    
    NSLog(@"RUNNING TIMER OF 300,000 SHA256,SHA512,SHA256,SHA512 LOOPS");
    NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];
    unsigned int z;
    for (z=0; z<300000; z++) {
        // Process first test
        SHA256_Init(&sha256);
        SHA256_Update(&sha256, inStrg, lngth);
        SHA256_Final(result256, &sha256);

        // Process first test
        SHA512_Init(&sha512);
        SHA512_Update(&sha512, inStrg, lngth);
        SHA512_Final(result512, &sha512);
        
        // Process second test
        SHA256_Init(&sha256);
        SHA256_Update(&sha256, inStrgB, lngthB);
        SHA256_Final(result256, &sha256);

        // Process second test
        SHA512_Init(&sha512);
        SHA512_Update(&sha512, inStrgB, lngthB);
        SHA512_Final(result512, &sha512);
    }
    NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - start;
    NSLog(@"TIMER: %f", duration);
    NSLog(@"");
    
    NSLog(@"====================");
    NSLog(@"TEST VECTORS");
    NSLog(@"====================");
    unsigned int i;
    NSMutableString *outStrg = [NSMutableString string];
    SHA256_Init(&sha256);
    SHA256_Update(&sha256, inStrg, lngth);
    SHA256_Final(result256, &sha256);
    for(i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        [outStrg appendFormat:@"%02x", result256[i]];
    }
    NSLog(@"''");
    NSLog(@"out256   : %@", outStrg);
    NSLog(@"should be: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    
    NSMutableString *outStrgB = [NSMutableString string];
    SHA512_Init(&sha512);
    SHA512_Update(&sha512, inStrg, lngth);
    SHA512_Final(result512, &sha512);
    for(i = 0; i < SHA512_DIGEST_LENGTH; i++) {
        [outStrgB appendFormat:@"%02x", result512[i]];
    }
    NSLog(@"out512   : %@", outStrgB);
    NSLog(@"should be: cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e");
    
    NSMutableString *outStrgC = [NSMutableString string];
    SHA256_Init(&sha256);
    SHA256_Update(&sha256, inStrgB, lngthB);
    SHA256_Final(result256, &sha256);
    for(i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        [outStrgC appendFormat:@"%02x", result256[i]];
    }
    NSLog(@"");
    NSLog(@"'The quick brown fox jumps over the lazy dog'");
    NSLog(@"out256   : %@", outStrgC);
    NSLog(@"should be: d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592");
    
    NSMutableString *outStrgD = [NSMutableString string];
    SHA512_Init(&sha512);
    SHA512_Update(&sha512, inStrgB, lngthB);
    SHA512_Final(result512, &sha512);
    for(i = 0; i < SHA512_DIGEST_LENGTH; i++) {
        [outStrgD appendFormat:@"%02x", result512[i]];
    }
    NSLog(@"out512   : %@", outStrgD);
    NSLog(@"should be: 07e547d9586f6a73f73fbac0435ed76951218fb7d0c8d788a309d785436bbb642e93a252a954f23912547d1e8a3b5ed6e1bfd7097821233fa0538f3db854fee6");
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
