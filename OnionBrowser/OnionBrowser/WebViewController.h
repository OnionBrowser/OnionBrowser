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

@property (strong, nonatomic) UIWebView *myWebView;
@property (nonatomic) UIToolbar* toolbar;
@property (nonatomic) UIBarButtonItem* backButton;
@property (nonatomic) UIBarButtonItem* forwardButton;
@property (nonatomic) UIBarButtonItem* refreshButton;
@property (nonatomic) UIBarButtonItem* stopButton;
@property (nonatomic) UILabel* pageTitleLabel;
@property (nonatomic) UITextField* addressField;

- (void)loadURL: (NSURL *)navigationURL;

- (void)updateButtons;
- (void)updateTitle:(UIWebView*)aWebView;
- (void)updateAddress:(NSURLRequest*)request;
- (void)loadAddress:(id)sender event:(UIEvent*)event;
- (void)informError:(NSError*)error;

@end
