//
//  WebViewController.h
//  OnionBrowser
//
//  Created by Mike Tigas on 2/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WebViewController : UIViewController <UIWebViewDelegate> {
}

@property (nonatomic, retain) UIWebView *myWebView;
@property (nonatomic, retain) UIToolbar* toolbar;
@property (nonatomic, retain) UIBarButtonItem* backButton;
@property (nonatomic, retain) UIBarButtonItem* forwardButton;
@property (nonatomic, retain) UIBarButtonItem* refreshButton;
@property (nonatomic, retain) UIBarButtonItem* stopButton;
@property (nonatomic, retain) UILabel* pageTitleLabel;
@property (nonatomic, retain) UITextField* addressField;

- (void)loadURL: (NSURL *)navigationURL;

- (void)updateButtons;
- (void)updateTitle:(UIWebView*)aWebView;
- (void)updateAddress:(NSURLRequest*)request;
- (void)loadAddress:(id)sender event:(UIEvent*)event;
- (void)informError:(NSError*)error;

@end
