//
//  Config.h
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 10.05.19.
//  Copyright © 2019 - 2023, Tigas Ventures, LLC (Mike Tigas)
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Config : NSObject

@property (class, nonatomic, assign, readonly, nonnull) NSString *extBundleId;

@end

NS_ASSUME_NONNULL_END
