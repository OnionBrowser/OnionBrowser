/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>

@protocol OnionManagerDelegate

- (void)torConnProgress: (NSInteger)progress;
- (void)torConnFinished;
- (void)torConnError;

@end
