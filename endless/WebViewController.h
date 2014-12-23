#import <UIKit/UIKit.h>
#import "IASKAppSettingsViewController.h"
#import "WebViewTab.h"
#import "WYPopoverController.h"

@interface WebViewController : UIViewController <UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, IASKSettingsDelegate, WYPopoverControllerDelegate>

- (NSMutableArray *)webViewTabs;
- (__strong WebViewTab *)curWebViewTab;
- (WebViewTab *)addNewTabForURL:(NSURL *)url;
- (void)removeTab:(NSNumber *)tabNumber andFocusTab:(NSNumber *)toFocus;
- (void)removeTab:(NSNumber *)tabNumber;
- (void)updateProgress;
- (void)updateSearchBarDetails;
- (void)refresh;
- (void)dismissPopover;

@end
