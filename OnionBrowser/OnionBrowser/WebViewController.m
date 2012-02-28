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
    self.myWebView = [[UIWebView alloc] initWithFrame:webFrame];
    self.myWebView.backgroundColor = [UIColor whiteColor];
    self.myWebView.scalesPageToFit = YES;
    self.myWebView.contentScaleFactor = 3;
    self.myWebView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    self.myWebView.delegate = self;
    [self.view addSubview: self.myWebView];
}

-(void)loadURL: (NSURL *)navigationURL {
    // partially covered by the nav bar
    CGRect webViewFrame = self.myWebView.frame;
    webViewFrame.origin.y = kNavBarHeight;
    webViewFrame.size.height = self.toolbar.frame.origin.y - webViewFrame.origin.y;
    self.myWebView.frame = webViewFrame;
    
    self.myWebView.delegate = self;
    self.myWebView.scalesPageToFit = YES;
    NSURLRequest *req = [[NSURLRequest requestWithURL:navigationURL] retain];
    [self.myWebView loadRequest:req];

    [self updateButtons];
}


- (void)viewDidLoad {
    [super viewDidLoad];

    self.toolbar = [[UIToolbar alloc] init];
    self.toolbar.frame = CGRectMake(0, self.view.frame.size.height-44, self.view.frame.size.width, 44);
    NSMutableArray *items = [[NSMutableArray alloc] init];
    UIBarButtonItem *space = [[[UIBarButtonItem alloc]
                               initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                               target:nil
                               action:nil] autorelease];
    
    self.backButton = [[[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:UIBarButtonSystemItemRewind
                    target:self.myWebView
                    action:@selector(goBack)] autorelease];
    self.stopButton = [[[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                    target:self.myWebView
                    action:@selector(stopLoading)] autorelease];
    self.refreshButton = [[[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                       target:self.myWebView
                       action:@selector(reload)] autorelease];
    self.forwardButton = [[[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemFastForward
                       target:self.myWebView
                       action:@selector(goForward)] autorelease];
    [items addObject:self.backButton];
    [items addObject:space];
    [items addObject:self.stopButton];
    [items addObject:space];
    [items addObject:self.refreshButton];
    [items addObject:space];
    [items addObject:self.forwardButton];
    [self.toolbar setItems:items animated:NO];
    [items release];
    [self.view addSubview:self.toolbar];
    [self.toolbar release];
    
    
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
    self.pageTitleLabel = label;
    [label release];
    
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
    self.addressField = address;
    [address release];
    
    [self.view addSubview:navBar];
    [navBar release];
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
    NSString* errorString = [NSString stringWithFormat:@"error %@",
                             error.localizedDescription];
    #ifdef DEBUG
        NSLog(@"[WebViewController] Error: %@", errorString);
    #endif
}



# pragma mark -



- (void)updateButtons
{
    self.forwardButton.enabled = self.myWebView.canGoForward;
    self.backButton.enabled = self.myWebView.canGoBack;
    self.stopButton.enabled = self.myWebView.loading;
}

- (void)updateTitle:(UIWebView*)aWebView
{
    NSString* pageTitle = [aWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
    self.pageTitleLabel.text = pageTitle; 
}

- (void)updateAddress:(NSURLRequest*)request
{
    NSURL* url = [request mainDocumentURL];
    NSString* absoluteString = [url absoluteString];
    self.addressField.text = absoluteString;
}

- (void)loadAddress:(id)sender event:(UIEvent *)event {
    NSString* urlString = self.addressField.text;
    NSURL* url = [NSURL URLWithString:urlString];
    if(!url.scheme)
    {
        NSString* modifiedURLString = [NSString stringWithFormat:@"http://%@", urlString];
        url = [NSURL URLWithString:modifiedURLString];
    }
    [self loadURL:url];
}

- (void)informError:(NSError *)error
{
    NSString* localizedDescription = [error localizedDescription];
    UIAlertView* alertView = [[UIAlertView alloc] 
                              initWithTitle:@"Error" 
                              message:localizedDescription delegate:nil 
                              cancelButtonTitle:@"OK" 
                              otherButtonTitles:nil];
    [alertView show];
    [alertView release];
}


@end
