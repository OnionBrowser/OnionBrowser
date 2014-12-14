#import <UIKit/UIKit.h>
#import "IASKAppSettingsViewController.h"

@interface WebViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIWebViewDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, IASKSettingsDelegate>

@property (strong, atomic) NSURL *curURL;

@end
