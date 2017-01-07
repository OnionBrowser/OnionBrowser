/*
 * Endless
 * Copyright (c) 2017 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "UIResponder+FirstResponder.h"

static __weak id currentFirstResponder;

@implementation UIResponder (FirstResponder)

+ (id)currentFirstResponder
{
	currentFirstResponder = nil;
	[[UIApplication sharedApplication] sendAction:@selector(findFirstResponder:) to:nil from:nil forEvent:nil];
	return currentFirstResponder;
}

- (void)findFirstResponder:(id)sender
{
	currentFirstResponder = self;
}

@end
