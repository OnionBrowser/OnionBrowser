/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import "Migration.h"

@implementation Migration

+ (void)migrate
{
    NSURL *storeUrl = [[[[NSFileManager defaultManager]
                         URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask]
                        lastObject]
                       URLByAppendingPathComponent:@"Settings.sqlite"];

    // Check, if CoreData SQLite file is there, if so migrate bookmarks and bridge settings.
    if ([storeUrl checkResourceIsReachableAndReturnError:nil])
    {
        // Initialize CoreData.
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:nil];

        NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc]
                                                     initWithManagedObjectModel:mom];

        NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [moc setPersistentStoreCoordinator:psc];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSPersistentStoreCoordinator *psc = [moc persistentStoreCoordinator];

            NSPersistentStore *store = [psc addPersistentStoreWithType:NSSQLiteStoreType
                              configuration:nil
                                        URL:storeUrl
                                    options:nil
                                      error:nil];

            // Migrate bookmarks.
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Bookmark"];
            [request setSortDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"order"
                                                                      ascending:YES]]];
            NSArray *oldBookmarks = [moc executeFetchRequest:request error:nil];

            NSMutableArray *newBookmarks = [Bookmark list];

            for (OldBookmark *ob in oldBookmarks) {
                Bookmark *nb = [[Bookmark alloc] init];
                nb.name = ob.title;
                nb.urlString = ob.url;

                [newBookmarks addObject:nb];
            }

            [Bookmark persistList];

            // Remove old CoreData storage.
            [psc removePersistentStore:store error:nil];
            [[NSFileManager defaultManager] removeItemAtURL:storeUrl error:nil];
        });
    }
}

@end
