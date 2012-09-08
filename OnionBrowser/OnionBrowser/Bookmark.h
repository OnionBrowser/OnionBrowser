//
//  Bookmark.h
//  OnionBrowser
//
//  Created by Mike Tigas on 9/7/12.
//
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Bookmark : NSManagedObject

@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * url;
@property (nonatomic) int16_t order;

@end
