// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <UIKit/UIKit.h>

@interface BookmarkTableViewController : UITableViewController {
    NSMutableArray *bookmarksArray;
    NSManagedObjectContext *managedObjectContext;
    UIBarButtonItem *addButton;
}

@property (nonatomic, retain) NSMutableArray *bookmarksArray;
@property (nonatomic, retain) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, retain) UIBarButtonItem *editButton;
@property (nonatomic, retain) UIBarButtonItem *addButton;
@property (nonatomic, retain) UIBarButtonItem *backButton;
@property (nonatomic, retain) UIBarButtonItem *editDoneButton;

@property (readonly, nonatomic) NSArray *presetBookmarks;

- (void)saveBookmarkOrder;

- (void)reload;
- (void)addBookmark;
- (void)startEditing;
- (void)stopEditing;
- (void)goBack;
@end
