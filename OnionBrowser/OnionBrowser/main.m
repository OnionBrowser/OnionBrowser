//
//  main.m
//  OnionBrowser
//
//  Copyright (c) 2012 Mike Tigas. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"

#import "ProxyURLProtocol.h"

int main(int argc, char *argv[])
{
    [NSURLProtocol registerClass:[ProxyURLProtocol class]];
    
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
