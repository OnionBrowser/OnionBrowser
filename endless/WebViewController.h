#import <UIKit/UIKit.h>
#import "NJKWebViewProgress.h"

@interface WebViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIWebViewDelegate, NJKWebViewProgressDelegate, UIGestureRecognizerDelegate>

@property (strong, atomic) NSURL *curURL;

@end
