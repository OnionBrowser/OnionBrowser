#import <UIKit/UIKit.h>
#import "IASKAppSettingsViewController.h"
#import "WebViewTab.h"

@interface WebViewController : UIViewController <UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, IASKSettingsDelegate>

- (NSMutableArray *)webViewTabs;
- (WebViewTab *)addNewTabForURL:(NSURL *)url;
- (void)removeTab:(NSNumber *)tabNumber andFocusTab:(NSNumber *)toFocus;
- (void)removeTab:(NSNumber *)tabNumber;
- (void)updateProgress;
- (void)updateSearchBarDetails;

@end
