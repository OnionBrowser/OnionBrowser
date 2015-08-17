#import <UIKit/UIKit.h>
#import "IASKAppSettingsViewController.h"
#import "WebViewTab.h"
#import "WYPopoverController.h"

@interface WebViewController : UIViewController <UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, IASKSettingsDelegate, WYPopoverControllerDelegate>

@property BOOL toolbarOnBottom;

- (NSMutableArray *)webViewTabs;
- (__strong WebViewTab *)curWebViewTab;

- (id)settingsButton;

- (void)viewIsVisible;

- (WebViewTab *)addNewTabForURL:(NSURL *)url;
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

@end
