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


static const NSInteger kNavBarTag = 1000;
static const NSInteger kAddressFieldTag = 1001;
static const NSInteger kAddressCancelButtonTag = 1002;
static const NSInteger kLoadingStatusTag = 1003;

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
            addressField = _addressField,
            currentURL = _currentURL,
            torStatus = _torStatus;

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

- (void)renderTorStatus: (NSString *)statusLine {
    UILabel *loadingStatus = (UILabel *)[self.view viewWithTag:kLoadingStatusTag];
                                                                       
    _torStatus = [NSString stringWithFormat:@"%@\n%@",
                  _torStatus, statusLine];
    NSRange progress_loc = [statusLine rangeOfString:@"BOOTSTRAP PROGRESS="];
    NSRange progress_r = {
        progress_loc.location+progress_loc.length,
        2
    };
    NSString *progress_str = @"";
    if (progress_loc.location != NSNotFound)
        progress_str = [statusLine substringWithRange:progress_r];

    NSRange summary_loc = [statusLine rangeOfString:@" SUMMARY="];
    NSString *summary_str = @"";
    if (summary_loc.location != NSNotFound)
        summary_str = [statusLine substringFromIndex:summary_loc.location+summary_loc.length+1];
    NSRange summary_loc2 = [summary_str rangeOfString:@"\""];
    if (summary_loc2.location != NSNotFound)
        summary_str = [summary_str substringToIndex:summary_loc2.location];

    NSString *status = [NSString stringWithFormat:@"Connecting to Tor network...\n%@%%\n%@",
                            progress_str,
                            summary_str];
    loadingStatus.text = status;
   
}

-(void)loadURL: (NSURL *)navigationURL {
    UIView *loadingStatus = [self.view viewWithTag:kLoadingStatusTag];
    if (loadingStatus != nil) {
        [loadingStatus removeFromSuperview];
    }

    // partially covered by the nav bar
    CGRect webViewFrame = _myWebView.frame;
    webViewFrame.origin.y = kNavBarHeight;
    webViewFrame.size.height = _toolbar.frame.origin.y - webViewFrame.origin.y;
    _myWebView.frame = webViewFrame;
    
    _myWebView.delegate = self;
    _myWebView.scalesPageToFit = YES;
    NSURLRequest *req = [NSURLRequest requestWithURL:navigationURL];
    
    [_myWebView loadRequest:req];

    [self updateButtons];
}


- (void)viewDidLoad {
    [super viewDidLoad];

    _toolbar = [[UIToolbar alloc] init];
    _toolbar.frame = CGRectMake(0, self.view.frame.size.height-44, self.view.frame.size.width, 44);
    _toolbar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _toolbar.contentMode = UIViewContentModeBottom;
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
    navBar.tag = kNavBarTag;
    navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    CGRect labelFrame = CGRectMake(kMargin, kSpacer, 
                                   navBar.bounds.size.width - 2*kMargin, kLabelHeight);
    UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.text = @"";
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
    address.returnKeyType = UIReturnKeyGo;
    address.autocorrectionType = UITextAutocorrectionTypeNo;
    address.autocapitalizationType = UITextAutocapitalizationTypeNone;
    address.clearButtonMode = UITextFieldViewModeNever;
    address.delegate = self;
    address.tag = kAddressFieldTag;
    [address addTarget:self 
                action:@selector(loadAddress:event:) 
      forControlEvents:UIControlEventEditingDidEndOnExit|UIControlEventEditingDidEnd];
    [navBar addSubview:address];
    _addressField = address;
    
    [self.view addSubview:navBar];
    
    CGRect screenFrame = [[UIScreen mainScreen] applicationFrame];
    UILabel *loadingStatus = [[UILabel alloc] initWithFrame:CGRectMake(0,
                                                                       kNavBarHeight,
                                                                       screenFrame.size.width,
                                                                       screenFrame.size.height-kNavBarHeight-44)];
    loadingStatus.tag = kLoadingStatusTag;
    loadingStatus.numberOfLines = 0;
    loadingStatus.font = [UIFont fontWithName:@"Helvetica" size:(20.0)];
    loadingStatus.lineBreakMode = UILineBreakModeWordWrap;
    loadingStatus.textAlignment =  UITextAlignmentLeft;
    [self.view addSubview:loadingStatus];
    

}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (IS_IPAD)
        return YES;
    else
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
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

- (void)addressBarCancel {
    _addressField.text = _currentURL;
    [_addressField resignFirstResponder];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];
        
    UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancelButton setTitle:@"Cancel" forState:UIControlStateHighlighted];
    [cancelButton setFrame:CGRectMake(navBar.bounds.size.width,
                                      kSpacer*2.0 + kLabelHeight,
                                      75 - 2*kMargin,
                                      kAddressHeight)];
    [cancelButton setHidden:NO];
    [cancelButton setEnabled:YES];
    [cancelButton addTarget:self action:@selector(addressBarCancel) forControlEvents:UIControlEventTouchUpInside];
    cancelButton.tag = kAddressCancelButtonTag;

    
    
    [UIView setAnimationsEnabled:YES];
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:UIViewAnimationCurveEaseInOut
                     animations:^{
                         _addressField.frame = CGRectMake(kMargin,
                                                          kSpacer*2.0 + kLabelHeight,
                                                          navBar.bounds.size.width - 2*kMargin - 75,
                                                          kAddressHeight);
                         
                         [cancelButton setFrame:CGRectMake(navBar.bounds.size.width - 75,
                                                           kSpacer*2.0 + kLabelHeight,
                                                           75 - kMargin,
                                                           kAddressHeight)];
                         [navBar addSubview:cancelButton];

                     }
                     completion:^(BOOL finished) {
                         _addressField.clearButtonMode = UITextFieldViewModeAlways;
                     }]; 
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];
    UIButton *cancelButton = (UIButton *)[self.view viewWithTag:kAddressCancelButtonTag];

    _addressField.clearButtonMode = UITextFieldViewModeNever;
    
    [UIView setAnimationsEnabled:YES];
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:UIViewAnimationCurveEaseInOut
                     animations:^{
                         _addressField.frame = CGRectMake(kMargin,
                                                          kSpacer*2.0 + kLabelHeight,
                                                          navBar.bounds.size.width - 2*kMargin,
                                                          kAddressHeight);
                         [cancelButton setFrame:CGRectMake(navBar.bounds.size.width,
                                                           kSpacer*2.0 + kLabelHeight,
                                                           75 - kMargin,
                                                           kAddressHeight)];
                     }
                     completion:^(BOOL finished) {
                         [cancelButton removeFromSuperview];
                     }]; 
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
    if (![absoluteString isEqualToString:_currentURL]){
        _currentURL = absoluteString;
        if ((!_addressField.isEditing) && ([_currentURL rangeOfString:@"file://"].location != 0)) {
            _addressField.text = absoluteString;
        }
    }
}

- (void)loadAddress:(id)sender event:(UIEvent *)event {
    NSString* urlString = _addressField.text;
    NSURL* url = [NSURL URLWithString:urlString];
    if(!url.scheme)
    {
        NSString *absUrl = [NSString stringWithFormat:@"http://%@", urlString];
        url = [NSURL URLWithString:absUrl];
    }
    _currentURL = [url absoluteString];
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
