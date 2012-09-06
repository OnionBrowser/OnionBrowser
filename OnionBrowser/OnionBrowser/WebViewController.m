//
//  WebViewController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 2/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WebViewController.h"
#import "AppDelegate.h"
#import "SettingsViewController.h"

static const CGFloat kNavBarHeight = 52.0f;
static const CGFloat kToolBarHeight = 44.0f;
static const CGFloat kLabelHeight = 14.0f;
static const CGFloat kMargin = 10.0f;
static const CGFloat kSpacer = 2.0f;
static const CGFloat kLabelFontSize = 12.0f;
static const CGFloat kAddressHeight = 26.0f;

static const NSInteger kNavBarTag = 1000;
static const NSInteger kAddressFieldTag = 1001;
static const NSInteger kAddressCancelButtonTag = 1002;
static const NSInteger kLoadingStatusTag = 1003;

static const Boolean kForwardButton = YES;
static const Boolean kBackwardButton = NO;

@interface WebViewController ()

@end

@implementation WebViewController

@synthesize myWebView = _myWebView,
            toolbar = _toolbar,
            backButton = _backButton,
            forwardButton = _forwardButton,
            toolButton = _toolButton,
            optionsMenu = _optionsMenu,
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
    CGRect webViewFrame = [[UIScreen mainScreen] applicationFrame];
    webViewFrame.origin.y = kNavBarHeight;
    webViewFrame.size.height = webViewFrame.size.height - kToolBarHeight - kNavBarHeight;
    _myWebView = [[UIWebView alloc] initWithFrame:webViewFrame];
    _myWebView.backgroundColor = [UIColor whiteColor];
    _myWebView.scalesPageToFit = YES;
    _myWebView.contentScaleFactor = 3;
    _myWebView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    _myWebView.delegate = self;
    [self.view addSubview: _myWebView];
}

- (void)renderTorStatus: (NSString *)statusLine {
    // TODO: really needs cleanup / prettiness
    //       (turn into semi-transparent modal with spinner?)
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

    NSString *status = [NSString stringWithFormat:@"Connecting… This may take a minute.\n\nIf this takes longer than 60 seconds, please close and re-open the app to retry connection initialization.\n\nIf this problem persists, please visit the following web page in another browser:\nhttp://onionbrowser.com/help/\n\n%@%%\n%@",
                            progress_str,
                            summary_str];
    loadingStatus.text = status;
   
}

-(void)loadURL: (NSURL *)navigationURL {
    // Remove the "connecting..." (initial tor load) overlay if it still exists.
    UIView *loadingStatus = [self.view viewWithTag:kLoadingStatusTag];
    if (loadingStatus != nil) {
        [loadingStatus removeFromSuperview];
    }

    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];

    // Build request and go.
    _myWebView.delegate = self;
    _myWebView.scalesPageToFit = YES;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:navigationURL];
    [req setHTTPShouldUsePipelining:appDelegate.usePipelining];
    [_myWebView loadRequest:req];

    _addressField.enabled = YES;
    _toolButton.enabled = YES;
    _refreshButton.enabled = YES;
    [self updateButtons];
}


- (UIImage *)makeForwardBackButtonImage:(Boolean)whichButton {
    // Draws the vector image for the forward or back button. (see kForwardButton
    // and kBackwardButton for the "whichButton" values)
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(nil,28*scale,28*scale,8,0,
                                                 colorSpace,kCGImageAlphaPremultipliedLast);
    CFRelease(colorSpace);
    CGColorRef fillColor = [[UIColor blackColor] CGColor];
    CGContextSetFillColor(context, CGColorGetComponents(fillColor));
    
    CGContextBeginPath(context);
    if (whichButton == kForwardButton) {
        CGContextMoveToPoint(context, 20.0f*scale, 12.0f*scale);
        CGContextAddLineToPoint(context, 4.0f*scale, 4.0f*scale);
        CGContextAddLineToPoint(context, 4.0f*scale, 22.0f*scale);
    } else {
        CGContextMoveToPoint(context, 8.0f*scale, 12.0f*scale);
        CGContextAddLineToPoint(context, 24.0f*scale, 4.0f*scale);
        CGContextAddLineToPoint(context, 24.0f*scale, 22.0f*scale);
    }
    CGContextClosePath(context);
    CGContextFillPath(context);
    
    CGImageRef theCGImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *buttonImage = [[UIImage alloc] initWithCGImage:theCGImage
                                                    scale:[[UIScreen mainScreen] scale]
                                              orientation:UIImageOrientationUp];
    CGImageRelease(theCGImage);
    return buttonImage;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Set up toolbar.
    _toolbar = [[UIToolbar alloc] init];
    [_toolbar setTintColor:[UIColor blackColor]];
    _toolbar.frame = CGRectMake(0, self.view.frame.size.height - kToolBarHeight, self.view.frame.size.width, kToolBarHeight);
    _toolbar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _toolbar.contentMode = UIViewContentModeBottom;
    NSMutableArray *items = [[NSMutableArray alloc] init];
    UIBarButtonItem *space = [[UIBarButtonItem alloc]
                               initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                               target:nil
                               action:nil];
        
    _backButton = [[UIBarButtonItem alloc] initWithImage:[self makeForwardBackButtonImage:kBackwardButton]
                    style:UIBarButtonItemStylePlain
                    target:self
                    action:@selector(goBack)];
    _forwardButton = [[UIBarButtonItem alloc] initWithImage:[self makeForwardBackButtonImage:kForwardButton]
                    style:UIBarButtonItemStylePlain
                    target:self
                    action:@selector(goForward)];
    _toolButton = [[UIBarButtonItem alloc]
                      initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                      target:self
                      action:@selector(openOptionsMenu)];
    _stopButton = [[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                    target:self
                    action:@selector(stopLoading)];
    _refreshButton = [[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                       target:self
                       action:@selector(reload)];

    _forwardButton.enabled = NO;
    _backButton.enabled = NO;
    _stopButton.enabled = NO;
    _toolButton.enabled = NO;
    _refreshButton.enabled = NO;

    [items addObject:_backButton];
    [items addObject:space];
    [items addObject:_forwardButton];
    [items addObject:space];
    [items addObject:_toolButton];
    [items addObject:space];
    [items addObject:_stopButton];
    [items addObject:space];
    [items addObject:_refreshButton];
    [_toolbar setItems:items animated:NO];
    [self.view addSubview:_toolbar];
    // (/toolbar)
    
    // Set up "action sheet" (options menu)
    _optionsMenu = [[UIActionSheet alloc] initWithTitle:nil
                                               delegate:self
                                      cancelButtonTitle:@"Close"
                                 destructiveButtonTitle:@"New Identity"
                                      otherButtonTitles:@"Browser Settings", @"Open Home Page", @"About Onion Browser", nil];
    // (/actionsheet)
    
    
    // Set up navbar
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
    
    [navBar setTintColor:[UIColor blackColor]];
    [label setTextColor:[UIColor whiteColor]];

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
    _addressField.enabled = NO;
    [self.view addSubview:navBar];
    // (/navbar)
    
    // Since this is first load: set up the overlay "loading..." bit that
    // will display tor initialization status.
    CGRect screenFrame = [[UIScreen mainScreen] applicationFrame];
    UILabel *loadingStatus = [[UILabel alloc] initWithFrame:CGRectMake(0,
                                                                       kNavBarHeight,
                                                                       screenFrame.size.width,
                                                                       screenFrame.size.height-kNavBarHeight*2)];
    [loadingStatus setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin];

    loadingStatus.tag = kLoadingStatusTag;
    loadingStatus.numberOfLines = 0;
    loadingStatus.font = [UIFont fontWithName:@"Helvetica" size:(18.0)];
    loadingStatus.lineBreakMode = UILineBreakModeWordWrap;
    loadingStatus.textAlignment =  UITextAlignmentLeft;
    loadingStatus.text = @"Connecting...\n\n\n\n\n";
    [self.view addSubview:loadingStatus];
}


- (void)viewDidUnload {
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Allow all four orientations on iPad.
    // Disallow upside-down for iPhone.
    return (IS_IPAD) || (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

# pragma mark -
# pragma mark WebView behavior

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

- (void)informError:(NSError *)error {
    if ([error.domain isEqualToString:@"NSOSStatusErrorDomain"] &&
        (error.code == -9807 || error.code == -9812)) {
        // Invalid certificate chain; valid cert chain, untrusted root

        UIAlertView* alertView = [[UIAlertView alloc]
                                  initWithTitle:@"SSL Error"
                                  message:@"Certificate chain is invalid. Either the site's SSL certificate is self-signed or the certificate was signed by an untrusted authority."
                                  delegate:nil
                                  cancelButtonTitle:@"Cancel"
                                  otherButtonTitles:@"Continue",nil];
        alertView.delegate = self;
        [alertView show];

    } else if ([error.domain isEqualToString:(NSString *)kCFErrorDomainCFNetwork] ||
               [error.domain isEqualToString:@"NSOSStatusErrorDomain"]) {
        NSString* errorDescription;
        
        if (error.code == kCFSOCKS5ErrorBadState) {
            errorDescription = @"Could not connect to the server. Either the domain name is incorrect, the server is inaccessible, or the Tor circuit was broken.";
        } else if (error.code == kCFHostErrorHostNotFound) {
            errorDescription = @"The server could not be found";
        } else {
            errorDescription = [NSString stringWithFormat:@"An error occurred: %@",
                                error.localizedDescription];
        }
        UIAlertView* alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Cannot Open Page"
                                  message:errorDescription delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];
    }
    #ifdef DEBUG
    else {
        NSLog(@"[WebViewController] uncaught error: %@", [error localizedDescription]);
        NSLog(@"\t -> %@", error.domain);
    }
    #endif
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        // "Continue anyway" for SSL cert error
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];

        // Assumung URL in address bar is the one that caused this error.
        NSURL *url = [NSURL URLWithString:_currentURL];
        NSString *hostname = url.host;
        [appDelegate.sslWhitelistedDomains addObject:hostname];

        UIAlertView* alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Whitelisted Domain"
                                  message:[NSString stringWithFormat:@"SSL certificate errors for '%@' will be ignored for the rest of this session.", hostname] delegate:nil 
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];

        // Reload (now that we have added host to whitelist)
        [self loadURL:url];
    }
}



# pragma mark -
# pragma mark Address Bar

- (void)addressBarCancel {
    _addressField.text = _currentURL;
    [_addressField resignFirstResponder];
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    // Stop loading if we are loading a page
    [_myWebView stopLoading];
    
    // Move a "cancel" button into the nav bar a la Safari.
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
# pragma mark Options Menu action sheet

- (void)openOptionsMenu {
    [_optionsMenu showFromToolbar:_toolbar];
}
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        ////////////////////////////////////////////////////////
        // New Identity
        ////////////////////////////////////////////////////////
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        [appDelegate.tor requestNewTorIdentity];
        
        NSHTTPCookie *cookie;
        NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (cookie in [storage cookies]) {
            [storage deleteCookie:cookie];
        }
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        
        // Initialize a new UIWebView (to clear the history of the previous one)
        UIWebView *newWebView = [[UIWebView alloc] initWithFrame:_myWebView.frame];
        newWebView.backgroundColor = [UIColor whiteColor];
        newWebView.scalesPageToFit = YES;
        newWebView.contentScaleFactor = 3;
        newWebView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
        newWebView.delegate = self;
        [_myWebView removeFromSuperview];
        _myWebView = newWebView;
        [self.view addSubview: _myWebView];
        
        // Reset forward/back buttons.
        [self updateButtons];
        
        // Reset the address field
        _addressField.text = @"";
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil 
                                                        message:@"Requesting a new IP address from Tor. Cache, cookies, and browser history cleared.\n\nDue to an iOS limitation, visisted links will still get the ':visited' CSS highlight state. iOS is resistant to script-based access to this information, but if you are still concerned about leaking history, please force-quit this app and re-launch. Please visit http://yu8.in/M5 for more detailed information."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK" 
                                              otherButtonTitles:nil];
        [alert show];
    } else if (buttonIndex == 1) {
        ////////////////////////////////////////////////////////
        // Settings Menu
        ////////////////////////////////////////////////////////
        SettingsViewController *settingsController = [[SettingsViewController alloc] initWithNibName:@"SettingsViewController" bundle:nil];
        [self presentModalViewController:settingsController animated:YES];
    }
    
    if ((buttonIndex == 0) || (buttonIndex == 2)) {
        ////////////////////////////////////////////////////////
        // New Identity OR Return To Home
        ////////////////////////////////////////////////////////
        NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
        resourcePath = [resourcePath stringByReplacingOccurrencesOfString:@"/" withString:@"//"];
        resourcePath = [resourcePath stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
        [self loadURL:[NSURL URLWithString: [NSString stringWithFormat:@"file:/%@//startup.html",resourcePath]]];
    } else if (buttonIndex == 3) {
        ////////////////////////////////////////////////////////
        // About Page
        ////////////////////////////////////////////////////////
        NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
        resourcePath = [resourcePath stringByReplacingOccurrencesOfString:@"/" withString:@"//"];
        resourcePath = [resourcePath stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
        [self loadURL:[NSURL URLWithString: [NSString stringWithFormat:@"file:/%@//about.html",resourcePath]]];
    }
}

# pragma mark -
# pragma mark Toolbar/navbar behavior

- (void)goForward {
    [_myWebView goForward];
    [self updateTitle:_myWebView];
    [self updateAddress:[_myWebView request]];
    [self updateButtons];
}
- (void)goBack {
    [_myWebView goBack];
    [self updateTitle:_myWebView];
    [self updateAddress:[_myWebView request]];
    [self updateButtons];
}
- (void)stopLoading {
    [_myWebView stopLoading];
    [self updateTitle:_myWebView];
    if ([_currentURL rangeOfString:@"file:"].location == 0) {
        _addressField.text = @"";
    } else {
        if (!_addressField.isEditing) {
            _addressField.text = _currentURL;
        }
    }
    [self updateButtons];
}
- (void)reload {
    [_myWebView reload];
    [self updateButtons];
}

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
    
    if ([absoluteString rangeOfString:@"file:"].location == 0) {
        _addressField.text = @"";
    } else if (![absoluteString isEqualToString:_currentURL]){
        _currentURL = absoluteString;
        if (!_addressField.isEditing) {
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

@end
