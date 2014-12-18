#import <UIKit/UIKit.h>
#import "IASKAppSettingsViewController.h"

@interface WebViewController : UIViewController <UITableViewDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, IASKSettingsDelegate>

- (NSMutableArray *)webViewTabs;
- (void)updateProgress;
- (void)updateSearchBarDetails;

@end
