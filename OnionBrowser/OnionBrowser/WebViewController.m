//
//  WebViewController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 2/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WebViewController.h"

static const CGFloat kNavBarHeight = 52.0f;
static const CGFloat kLabelHeight = 14.0f;
static const CGFloat kMargin = 10.0f;
static const CGFloat kSpacer = 2.0f;
static const CGFloat kLabelFontSize = 12.0f;
static const CGFloat kAddressHeight = 26.0f;


@interface WebViewController ()

@end

@implementation WebViewController

@synthesize myWebView = _myWebView,
            toolbar = _toolbar,
            backButton = _backButton,
            forwardButton = _forwardButton,
            refreshButton = _refreshButton,
            stopButton = _stopButton,
            pageTitleLabel = _pageTitleLabel,
            addressField = _addressField;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {

    }
    return self;
}

-(void)loadView {
    UIView *contentView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    self.view = contentView;
    CGRect webFrame = [[UIScreen mainScreen] applicationFrame];
    webFrame.origin.y = 0.0f;
    _myWebView = [[UIWebView alloc] initWithFrame:webFrame];
    _myWebView.backgroundColor = [UIColor whiteColor];
    _myWebView.scalesPageToFit = YES;
    _myWebView.contentScaleFactor = 3;
    _myWebView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    _myWebView.delegate = self;
    [self.view addSubview: _myWebView];
}

-(void)loadURL: (NSURL *)navigationURL {
    // partially covered by the nav bar
    CGRect webViewFrame = _myWebView.frame;
    webViewFrame.origin.y = kNavBarHeight;
    webViewFrame.size.height = _toolbar.frame.origin.y - webViewFrame.origin.y;
    _myWebView.frame = webViewFrame;
    
    _myWebView.delegate = self;
    _myWebView.scalesPageToFit = YES;
    NSURLRequest *req = [NSURLRequest requestWithURL:navigationURL];
    
    NSLog(@"loading first request");
    [_myWebView loadRequest:req];

    [self updateButtons];
}


- (void)viewDidLoad {
    [super viewDidLoad];

    _toolbar = [[UIToolbar alloc] init];
    _toolbar.frame = CGRectMake(0, self.view.frame.size.height-44, self.view.frame.size.width, 44);
    NSMutableArray *items = [[NSMutableArray alloc] init];
    UIBarButtonItem *space = [[UIBarButtonItem alloc]
                               initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                               target:nil
                               action:nil];
    
    _backButton = [[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:UIBarButtonSystemItemRewind
                    target:_myWebView
                    action:@selector(goBack)];
    _stopButton = [[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                    target:_myWebView
                    action:@selector(stopLoading)];
    _refreshButton = [[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                       target:_myWebView
                       action:@selector(reload)];
    _forwardButton = [[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward
                       target:_myWebView
                       action:@selector(goForward)];
    [items addObject:_backButton];
    [items addObject:space];
    [items addObject:_stopButton];
    [items addObject:space];
    [items addObject:_refreshButton];
    [items addObject:space];
    [items addObject:_forwardButton];
    [_toolbar setItems:items animated:NO];
    [self.view addSubview:_toolbar];
    
    
    CGRect navBarFrame = self.view.bounds;
    navBarFrame.size.height = kNavBarHeight;
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    CGRect labelFrame = CGRectMake(kMargin, kSpacer, 
                                   navBar.bounds.size.width - 2*kMargin, kLabelHeight);
    UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.text = @"Page Title";
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont systemFontOfSize:12];
    label.textAlignment = UITextAlignmentCenter;
    [navBar addSubview:label];
    _pageTitleLabel = label;
    
    // The address field is the same with as the label and located just below 
    // it with a gap of kSpacer
    CGRect addressFrame = CGRectMake(kMargin, kSpacer*2.0 + kLabelHeight, 
                                     labelFrame.size.width, kAddressHeight);
    UITextField *address = [[UITextField alloc] initWithFrame:addressFrame];
    address.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    address.borderStyle = UITextBorderStyleRoundedRect;
    address.font = [UIFont systemFontOfSize:17];
    address.keyboardType = UIKeyboardTypeURL;
    address.autocapitalizationType = UITextAutocapitalizationTypeNone;
    address.clearButtonMode = UITextFieldViewModeWhileEditing;
    [address addTarget:self 
                action:@selector(loadAddress:event:) 
      forControlEvents:UIControlEventEditingDidEndOnExit];
    [navBar addSubview:address];
    _addressField = address;
    
    [self.view addSubview:navBar];
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

# pragma mark -

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    [self updateAddress:request];
    return YES;
}

 - (void)webViewDidStartLoad:(UIWebView *)webView {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [self updateButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self updateButtons];
    [self updateTitle:webView];
    NSURLRequest* request = [webView request];
    [self updateAddress:request];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

    [self updateButtons];
    [self informError:error];
    #ifdef DEBUG
        NSString* errorString = [NSString stringWithFormat:@"error %@",
                                 error.localizedDescription];
        NSLog(@"[WebViewController] Error: %@", errorString);
    #endif
}



# pragma mark -



- (void)updateButtons
{
    _forwardButton.enabled = _myWebView.canGoForward;
    _backButton.enabled = _myWebView.canGoBack;
    _stopButton.enabled = _myWebView.loading;
}

- (void)updateTitle:(UIWebView*)aWebView
{
    NSString* pageTitle = [aWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
    _pageTitleLabel.text = pageTitle; 
}

- (void)updateAddress:(NSURLRequest*)request
{
    NSURL* url = [request mainDocumentURL];
    NSString* absoluteString = [url absoluteString];
    _addressField.text = absoluteString;
}

- (void)loadAddress:(id)sender event:(UIEvent *)event {
    NSString* urlString = _addressField.text;
    NSURL* url = [NSURL URLWithString:urlString];
    if(!url.scheme)
    {
        NSString* modifiedURLString = [NSString stringWithFormat:@"http://%@", urlString];
        url = [NSURL URLWithString:modifiedURLString];
    }
    [self loadURL:url];
}

- (void)informError:(NSError *)error {
    if ([error.domain isEqualToString:(NSString *)kCFErrorDomainCFNetwork]) {
        NSString* errorDescription;
        
        if (error.code == kCFSOCKS5ErrorBadState) {
            errorDescription = @"Could not connect to the server. Either the domain name is incorrect, the server is inaccessible, or the Tor circuit was broken.";
        } else if (error.code == kCFHostErrorHostNotFound) {
            errorDescription = @"The server could not be found";
        } else {
            errorDescription = [NSString stringWithFormat:@"An unknown error occurred: %@",
                                error.localizedDescription];
        }
        UIAlertView* alertView = [[UIAlertView alloc] 
                                  initWithTitle:@"Cannot Open Page" 
                                  message:errorDescription delegate:nil 
                                  cancelButtonTitle:@"OK" 
                                  otherButtonTitles:nil];
        [alertView show];
        
    }
}


@end
