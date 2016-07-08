//
//  BridgeViewController.h
//  OnionBrowser
//
//  Created by Mike Tigas on 7/8/16.
//
//

#import <UIKit/UIKit.h>

@interface BridgeViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (nonatomic, retain) UIBarButtonItem *backButton;
- (void)goBack;

@end
