//
//  OldBookmark.h
//  OnionBrowser2
//
//  Copyright © 2012 - 2021, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface OldBookmark : NSManagedObject

@property (nonatomic) int16_t order;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * url;

@end
