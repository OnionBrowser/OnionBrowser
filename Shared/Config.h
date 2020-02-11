//
//  Config.h
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 10.05.19.
//  Copyright © 2019 jcs. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Config : NSObject

@property (class, nonatomic, assign, readonly, nonnull) NSString *extBundleId NS_REFINED_FOR_SWIFT;

@property (class, nonatomic, assign, readonly, nonnull) NSString *groupId NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END
