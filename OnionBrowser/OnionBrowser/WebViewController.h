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
@property (nonatomic, retain) UIActivityIndicatorView *activityIndicator;

-(void)loadURL: (NSURL *)navigationURL;

@end
