#import <UIKit/UIKit.h>
#import "IASKAppSettingsViewController.h"

@interface WebViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, IASKSettingsDelegate>

- (NSMutableArray *)webViewTabs;
- (void)updateProgress;
- (void)updateSearchBarDetails;

@end
