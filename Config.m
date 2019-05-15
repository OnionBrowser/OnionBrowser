//
//  Config.m
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 10.05.19.
//  Copyright © 2019 jcs. All rights reserved.
//

#import "Config.h"

#define MACRO_STRING_(m) #m
#define MACRO_STRING(m) @MACRO_STRING_(m)

@implementation Config

+ (NSString *) extBundleId {
	return MACRO_STRING(OB_EXT_BUNDLE_ID);
}

@end
