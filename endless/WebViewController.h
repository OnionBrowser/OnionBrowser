#import <UIKit/UIKit.h>
#import "NJKWebViewProgress.h"

@interface WebViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UIWebViewDelegate, NJKWebViewProgressDelegate>

@property (strong, nonatomic) NSURL *curURL;

@end
