#import <UIKit/UIKit.h>
#import "NJKWebViewProgress.h"

@interface WebViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIWebViewDelegate, NJKWebViewProgressDelegate, UIGestureRecognizerDelegate, UIScrollViewDelegate>

@property (strong, atomic) NSURL *curURL;

@end
