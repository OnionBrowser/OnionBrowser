#import <UIKit/UIKit.h>
#import "NJKWebViewProgress.h"
#import "IASKAppSettingsViewController.h"

@interface WebViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIWebViewDelegate, NJKWebViewProgressDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate, IASKSettingsDelegate>

@property (strong, atomic) NSURL *curURL;

@end
