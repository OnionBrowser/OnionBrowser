/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>
#import "IASKAppSettingsViewController.h"
#import "WebViewTab.h"
#import "WYPopoverController.h"

#define TOOLBAR_HEIGHT 47
#define TOOLBAR_PADDING 6
#define TOOLBAR_BUTTON_SIZE 30

@interface WebViewController : UIViewController <UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, IASKSettingsDelegate, WYPopoverControllerDelegate>

@property BOOL toolbarOnBottom;
@property BOOL darkInterface;

- (void)focusUrlField;

- (NSMutableArray *)webViewTabs;
- (__strong WebViewTab *)curWebViewTab;

- (UIButton *)settingsButton;

- (void)viewIsVisible;
- (void)viewIsNoLongerVisible;

- (WebViewTab *)addNewTabForURL:(NSURL *)url;
- (WebViewTab *)addNewTabForURL:(NSURL *)url forRestoration:(BOOL)restoration withCompletionBlock:(void(^)(BOOL))block;
- (void)switchToTab:(NSNumber *)tabNumber;
- (void)removeTab:(NSNumber *)tabNumber andFocusTab:(NSNumber *)toFocus;
- (void)removeTab:(NSNumber *)tabNumber;
- (void)removeAllTabs;

- (void)webViewTouched;
- (void)updateProgress;
- (void)updateSearchBarDetails;
- (void)refresh;
- (void)forceRefresh;
- (void)dismissPopover;
- (void)prepareForNewURLFromString:(NSString *)url;
- (void)showBookmarksForEditing:(BOOL)editing;
- (void)hideBookmarks;

@end
