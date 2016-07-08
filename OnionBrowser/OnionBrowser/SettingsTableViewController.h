#import <UIKit/UIKit.h>

@interface SettingsTableViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (nonatomic, retain) UIBarButtonItem *backButton;
- (void)goBack;

@end
