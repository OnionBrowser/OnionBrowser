//
//  WebViewController.h
//  OnionBrowser
//
//  Created by Mike Tigas on 2/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ASIHTTPRequest.h"

@interface WebViewController : UIViewController 

@property (nonatomic, retain) NSString *urlName;
@property (nonatomic, retain) UIWebView *myWebView;
@property (nonatomic, retain) UIActivityIndicatorView *activityIndicator;

-(id)initWithUrl:(NSString *)url;

-(void)startLoad;

@end
