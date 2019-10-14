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

#define ABOUT_ONION_BROWSER @"about:onion-browser"

/* this just detects the iPhone X by its notch */
#define HAS_OLED ([[[[UIApplication sharedApplication] delegate] window] safeAreaInsets].bottom > 0)

typedef NS_ENUM(NSInteger, WebViewTabAnimation) {
    WebViewTabAnimationDefault,
    WebViewTabAnimationHidden,
    WebViewTabAnimationQuick,
};

@interface WebViewController : UIViewController <UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, IASKSettingsDelegate, WYPopoverControllerDelegate>

- (void)focusUrlField;
- (void)unfocusUrlField;

- (NSMutableArray *)webViewTabs;
- (__strong WebViewTab *)curWebViewTab;

- (UIButton *)settingsButton;

- (void)viewIsVisible;
- (void)viewIsNoLongerVisible;

- (WebViewTab *)addNewTabForURL:(NSURL *)url;
- (WebViewTab *)addNewTabForURL:(NSURL *)url forRestoration:(BOOL)restoration withAnimation:(WebViewTabAnimation)animation withCompletionBlock:(void(^)(BOOL finished))block;
- (void)addNewTabFromToolbar:(id)_id;
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
- (void)showBookmarks;
- (void)hideBookmarks;
- (void)hideSearchResults;

@end
