//
//  WebViewController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 2/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WebViewController.h"

@interface WebViewController ()

@end

@implementation WebViewController

@synthesize urlName = _urlName, myWebView = _myWebView, activityIndicator = _activityIndicator;

- (id)initWithUrl:(NSString *)url{
    self = [super init];
    if (self) {
        _urlName = [url retain];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

-(void)loadView {
    //[super loadView];
    NSLog(@"loading webview");
    
    UIView *contentView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    self.view = contentView;
    CGRect webFrame = [[UIScreen mainScreen] applicationFrame];
    webFrame.origin.y = 0.0f;
    NSLog(@"loading webview2");
    _myWebView = [[UIWebView alloc] initWithFrame:webFrame];
    _myWebView.backgroundColor = [UIColor whiteColor];
    _myWebView.scalesPageToFit = YES;
    _myWebView.contentScaleFactor = 3;
    _myWebView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    _myWebView.delegate = nil;
    NSLog(@"loading webview3");
    [self.view addSubview: _myWebView];
    _activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _activityIndicator.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
    _activityIndicator.center = self.view.center;
    [self.view addSubview: _activityIndicator];
}

-(void)startLoad { 
    NSURL *navigationURL = [[NSURL alloc] initWithString:_urlName];
    __block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:navigationURL];
    [request setProxyHost:@"127.0.0.1"];
    [request setProxyPort:60601];
    [request setProxyType:(NSString *)kCFProxyTypeSOCKS];
    [request setCompletionBlock:^{
        // Use when fetching text data
        NSString *responseString = [request responseString];
        [_myWebView loadHTMLString:responseString baseURL:nil];
    }];
    [request setFailedBlock:^{
        NSError *error = [request error];
        NSString* errorString = [NSString stringWithFormat:@"error %@",
                                 error.localizedDescription];
        NSLog(@"error: %@", errorString);
        [_myWebView loadHTMLString:errorString baseURL:nil];
    }];
    [request startSynchronous];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
/*
- (void)webViewDidStartLoad:(UIWebView *)webView
{
    // starting the load, show the activity indicator in the status bar
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [_activityIndicator startAnimating];
    NSLog(@"starting load");
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    // finished loading, hide the activity indicator in the status bar
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [_activityIndicator stopAnimating];
    NSLog(@"loaded");
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    // load error, hide the activity indicator in the status bar
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    // report the error inside the webview
    NSString* errorString = [NSString stringWithFormat:@"error %@",
                             error.localizedDescription];
    NSLog(@"error: %@", errorString);
    [_myWebView loadHTMLString:errorString baseURL:nil];
}
*/
@end
