//
//  WebViewController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 2/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "WebViewController.h"
#import "AppDelegate.h"
#import "BookmarkTableViewController.h"
#import "SettingsViewController.h"
#import "Bookmark.h"
#import "BridgeTableViewController.h"
#import "NJKWebViewProgressView.h"
#import <objc/runtime.h>

#define ALERTVIEW_SSL_WARNING 1
#define ALERTVIEW_EXTERN_PROTO 2
#define ALERTVIEW_INCOMING_URL 3

static const CGFloat kNavBarHeight = 52.0f;
static const CGFloat kToolBarHeight = 44.0f;
static const CGFloat kLabelHeight = 14.0f;
static const CGFloat kMargin = 10.0f;
static const CGFloat kSpacer = 2.0f;
static const CGFloat kSpacer7 = 3.5f;
//static const CGFloat kLabelFontSize = 12.0f;
static const CGFloat kAddressHeight = 26.0f;

static const NSInteger kNavBarTag = 1000;
static const NSInteger kAddressFieldTag = 1001;
static const NSInteger kAddressCancelButtonTag = 1002;
static const NSInteger kLoadingStatusTag = 1003;

static const Boolean kForwardButton = YES;
static const Boolean kBackwardButton = NO;

@interface WebViewController ()

@end

const char AlertViewExternProtoUrl;
const char AlertViewIncomingUrl;

@implementation WebViewController {
    NJKWebViewProgressView *_progressView;
    NJKWebViewProgress *_progressProxy;
}

@synthesize myWebView = _myWebView,
            toolbar = _toolbar,
            backButton = _backButton,
            forwardButton = _forwardButton,
            toolButton = _toolButton,
            optionsMenu = _optionsMenu,
            bookmarkButton = _bookmarkButton,
            stopRefreshButton = _stopRefreshButton,
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
    self.view = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
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

    NSString *status = [NSString stringWithFormat:@"Connecting… %@%%\n%@\n\nIf this takes longer than a minute, please close and re-open the app.\n\nIf problem persists, you can try connecting via Tor bridges by\npressing the middle (settings)\nbutton below.\n\nVisit the site below if you need help\nwith bridges or if you continue\nto have issues:\nonionbrowser.com/help",
                            progress_str,
                            summary_str];
    loadingStatus.text = status;
}

-(void)askToLoadURL: (NSURL *)navigationURL {
    /* Used on startup, if we opened the app from an outside source.
     * Will ask for user permission and display requested URL so that
     * the user isn't tricked into visiting a URL that includes their
     * IP address (or other info) that an attack site included when the user
     * was on the attack site outside of Tor.
     */
    NSString *msg = [NSString stringWithFormat: @"Another app has requested that Onion Browser load the following link. Because the link is generated outside of Tor, please ensure that you trust the link & that the URL does not contain identifying information. Canceling will open the normal homepage.\n\n%@", navigationURL.absoluteString, nil];
    UIAlertView* alertView = [[UIAlertView alloc]
                              initWithTitle:@"Open This URL?"
                              message:msg
                              delegate:nil
                              cancelButtonTitle:@"Cancel"
                              otherButtonTitles:@"Open This Link",nil];
    alertView.delegate = self;
    alertView.tag = ALERTVIEW_INCOMING_URL;
    [alertView show];
    objc_setAssociatedObject(alertView, &AlertViewIncomingUrl, navigationURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


-(void)loadURL: (NSURL *)navigationURL {
    NSString *urlProto = [navigationURL scheme];
    if ([urlProto isEqualToString:@"onionbrowser"]||[urlProto isEqualToString:@"onionbrowsers"]||[urlProto isEqualToString:@"http"]||[urlProto isEqualToString:@"https"]) {
        /***** One of our supported protocols *****/
        
        // Remove the "connecting..." (initial tor load) overlay if it still exists.
        UIView *loadingStatus = [self.view viewWithTag:kLoadingStatusTag];
        if (loadingStatus != nil) {
            [loadingStatus removeFromSuperview];
            
            // now add the "progress bar" to the view, too
            UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];
            CGRect navBarFrame = navBar.frame;
            CGFloat progressBarHeight = 2.5f;
            CGRect barFrame = CGRectMake(0, navBarFrame.size.height - progressBarHeight, navBarFrame.size.width, progressBarHeight);
            _progressView = [[NJKWebViewProgressView alloc] initWithFrame:barFrame];
            [navBar addSubview:_progressView];
        }

        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        // Build request and go.
        _myWebView.delegate = _progressProxy;
        _progressProxy.webViewProxyDelegate = self;
        _progressProxy.progressDelegate = self;
        _myWebView.scalesPageToFit = YES;
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:navigationURL];
        [req setHTTPShouldUsePipelining:[[settings valueForKey:@"pipelining"] integerValue]];
        [_myWebView loadRequest:req];

        _addressField.enabled = YES;
        _toolButton.enabled = YES;
        _stopRefreshButton.enabled = YES;
        _bookmarkButton.enabled = YES;
        [self updateButtons];
    } else {
        /***** NOT a protocol that this app speaks, check with the OS if the user wants to *****/
        if ([[UIApplication sharedApplication] canOpenURL:navigationURL]) {
            //NSLog(@"can open %@", [navigationURL absoluteString]);
            NSString *msg = [NSString stringWithFormat: @"Onion Browser cannot load a '%@' link, but another app you have installed can.\n\nNote that the other app will not load data over Tor, which could leak identifying information.\n\nDo you wish to proceed?", navigationURL.scheme, nil];
            UIAlertView* alertView = [[UIAlertView alloc]
                                      initWithTitle:@"Open Other App?"
                                      message:msg
                                      delegate:nil
                                      cancelButtonTitle:@"Cancel"
                                      otherButtonTitles:@"Open",nil];
            alertView.delegate = self;
            alertView.tag = ALERTVIEW_EXTERN_PROTO;
            [alertView show];
            objc_setAssociatedObject(alertView, &AlertViewExternProtoUrl, navigationURL, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        } else {
            //NSLog(@"cannot open %@", [navigationURL absoluteString]);
            [self addressBarCancel];
            return;
        }
    }
}


- (UIImage *)makeForwardBackButtonImage:(Boolean)whichButton {
    // Draws the vector image for the forward or back button. (see kForwardButton
    // and kBackwardButton for the "whichButton" values)
    CGFloat scale = [[UIScreen mainScreen] scale];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(nil,28*scale,28*scale,8,0,
                                                 colorSpace,kCGBitmapAlphaInfoMask & kCGImageAlphaPremultipliedLast);
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

    /********** Initialize UIWebView **********/
    // Initialize a new UIWebView (to clear the history of the previous one)
    CGSize size = [UIScreen mainScreen].bounds.size;
    
    // Flip if we are rotated
    //if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
    //    size = CGSizeMake(size.height, size.width);
    //}
    
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    NSString *reqSysVer = @"7.0";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    if (
        ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending) &&
        ([appDelegate deviceType] == X_DEVICE_IS_IPAD)
    ){
        // 7.0+, iPad
    } else {
        size.height -= 20.0f;
    }
    size.height -= kToolBarHeight;
    size.height -= kNavBarHeight;
    
    CGRect webViewFrame = [[UIScreen mainScreen] applicationFrame];
    webViewFrame.origin.y = kNavBarHeight;
    webViewFrame.origin.x = 0;
    webViewFrame.size = size;
    
    _progressProxy = [[NJKWebViewProgress alloc] init];

    _myWebView = [[UIWebView alloc] initWithFrame:webViewFrame];
    _myWebView.backgroundColor = [UIColor whiteColor];
    _myWebView.scalesPageToFit = YES;
    _myWebView.contentScaleFactor = 3;
    _myWebView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    _myWebView.delegate = _progressProxy;
    _progressProxy.webViewProxyDelegate = self;
    _progressProxy.progressDelegate = self;
    [self.view addSubview: _myWebView];
    
    /********** Create Toolbars **********/
    // Set up toolbar.
    _toolbar = [[UIToolbar alloc] init];
    [_toolbar setTintColor:[UIColor blackColor]];
    _toolbar.frame = CGRectMake(0, self.view.frame.size.height - kToolBarHeight, self.view.frame.size.width, kToolBarHeight);
    _toolbar.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _toolbar.contentMode = UIViewContentModeBottom;
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
    _bookmarkButton = [[UIBarButtonItem alloc]
                   initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks
                   target:self
                   action:@selector(showBookmarks)];
    _stopRefreshButton = [[UIBarButtonItem alloc]
                    initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                    target:self
                    action:@selector(stopLoading)];

    _forwardButton.enabled = NO;
    _backButton.enabled = NO;
    _stopRefreshButton.enabled = NO;
    _toolButton.enabled = YES;
    _bookmarkButton.enabled = NO;

    NSMutableArray *items = [[NSMutableArray alloc] init];
    [items addObject:_backButton];
    [items addObject:space];
    [items addObject:_forwardButton];
    [items addObject:space];
    [items addObject:_toolButton];
    [items addObject:space];
    [items addObject:_bookmarkButton];
    [items addObject:space];
    [items addObject:_stopRefreshButton];
    [_toolbar setItems:items animated:NO];
    
    [self.view addSubview:_toolbar];
    // (/toolbar)
    
    // Set up actionsheets (options menu, bookmarks menu)
    _optionsMenu = [[UIActionSheet alloc] initWithTitle:nil
                                               delegate:self
                                      cancelButtonTitle:@"Close"
                                 destructiveButtonTitle:@"New Identity"
                                      otherButtonTitles:@"Bookmark Current Page", @"Browser Settings", @"Open Home Page", @"About Onion Browser", @"Help / Support", nil];
    // (/actionsheets)
    
    
    /********** Set Up Navbar **********/
    CGRect navBarFrame = self.view.bounds;
    navBarFrame.size.height = kNavBarHeight;
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:navBarFrame];
    navBar.tag = kNavBarTag;
    navBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    CGRect labelFrame = CGRectMake(kMargin, kSpacer,
                                   navBar.bounds.size.width - 2*kMargin, kLabelHeight);

    /* if iOS < 7.0 */
    if ([currSysVer compare:reqSysVer options:NSNumericSearch] == NSOrderedAscending) {
        UILabel *label = [[UILabel alloc] initWithFrame:labelFrame];
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        label.text = @"";
        label.backgroundColor = [UIColor clearColor];
        label.font = [UIFont systemFontOfSize:12];
        label.textAlignment = NSTextAlignmentCenter;
        
        [navBar setTintColor:[UIColor blackColor]];
        [label setTextColor:[UIColor whiteColor]];
        
        [navBar addSubview:label];
        _pageTitleLabel = label;
    }
    /* endif */
    
    // The address field is the same with as the label and located just below 
    // it with a gap of kSpacer
    CGRect addressFrame;
    if ([currSysVer compare:reqSysVer options:NSNumericSearch] == NSOrderedAscending) {
        /* if iOS < 7.0 */
        addressFrame = CGRectMake(kMargin, kSpacer*2.0 + kLabelHeight,
                                     labelFrame.size.width, kAddressHeight);
    } else {
        /*  iOS 7.0+ */
        addressFrame = CGRectMake(kMargin, kSpacer7*2.0 + kLabelHeight,
                                         labelFrame.size.width, kAddressHeight);
    }
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
    loadingStatus.lineBreakMode = NSLineBreakByWordWrapping;
    loadingStatus.textAlignment =  NSTextAlignmentCenter;
    loadingStatus.text = @"Connecting...\n\n\n\n\n";
    [self.view addSubview:loadingStatus];
    if (appDelegate.doPrepopulateBookmarks){
        [self prePopulateBookmarks];
    }
}

-(void) prePopulateBookmarks {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
    NSManagedObjectContext *context = [appDelegate managedObjectContext];

    NSUInteger i = 0;
    
    Bookmark *bookmark;

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"DuckDuckGo Search (.onion)"];
    [bookmark setUrl:@"https://3g2upl4pq6kufc4m.onion/html/"];
    [bookmark setOrder:i++];
    
    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"DuckDuckGo Search (HTTPS)"];
    [bookmark setUrl:@"https://duckduckgo.com/html/"];
    [bookmark setOrder:i++];
    
    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"StartPage Search Engine"];
    [bookmark setUrl:@"https://startpage.com/m/"];
    [bookmark setOrder:i++];
    
    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"ifconfig.me Identity Check"];
    [bookmark setUrl:@"http://ifconfig.me/"];
    [bookmark setOrder:i++];
    

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"The Tor Project"];
    [bookmark setUrl:@"http://idnxcnkne4qt76tg.onion/"];
    [bookmark setOrder:i++];
    
    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"Tor Project News"];
    [bookmark setUrl:@"https://blog.torproject.org/"];
    [bookmark setOrder:i++];
    
    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"Electronic Frontier Foundation"];
    [bookmark setUrl:@"https://www.eff.org/"];
    [bookmark setOrder:i++];
    
    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"Tactical Technology Collective"];
    [bookmark setUrl:@"https://tacticaltech.org/"];
    [bookmark setOrder:i++];
    
    NSError *error = nil;
    if (![context save:&error]) {
        NSLog(@"Error adding bookmarks: %@", error);
    }
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
    if ([[[request URL] scheme] isEqualToString:@"data"]) {
        NSString *url = [[request URL] absoluteString];
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:@"\\Adata:image/(?:jpe?g|gif|png)"
                                      options:NSRegularExpressionCaseInsensitive
                                      error:nil];
        NSUInteger numberOfMatches = [regex numberOfMatchesInString:url
                                                              options:0
                                                                range:NSMakeRange(0, [url length])];
        if (numberOfMatches == 0) {
            // This is a "data:" URI that isn't an image. Since this could be an HTML page,
            // PDF file, or other dynamic document, we should block it.
            // TODO: for now, this is silent
            return NO;
        }
    }
    [self updateAddress:request];
    return YES;
}

 - (void)webViewDidStartLoad:(UIWebView *)webView {
    [self updateButtons];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    [self updateButtons];
    [self updateTitle:webView];
    NSURLRequest* request = [webView request];
    [self updateAddress:request];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
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
                                  initWithTitle:@"Cannot Verify Website Identity"
                                  message:@"Either the site's SSL certificate is self-signed or the certificate was signed by an untrusted authority.\n\nFor normal websites, it is generally unsafe to proceed.\n\nFor .onion websites (or sites using CACert or self-signed certificates), only proceed if you think you can trust this website's URL."
                                  delegate:nil
                                  cancelButtonTitle:@"Cancel"
                                  otherButtonTitles:@"Continue",nil];
        alertView.delegate = self;
        alertView.tag = ALERTVIEW_SSL_WARNING;
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
    if ((alertView.tag == ALERTVIEW_SSL_WARNING) && (buttonIndex == 1)) {
        // "Continue anyway" for SSL cert error
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];

        // Assumung URL in address bar is the one that caused this error.
        NSURL *url = [NSURL URLWithString:_currentURL];
        NSString *hostname = url.host;
        [appDelegate.sslWhitelistedDomains addObject:hostname];

        UIAlertView* newAlertView = [[UIAlertView alloc]
                                  initWithTitle:@"Whitelisted Domain"
                                  message:[NSString stringWithFormat:@"SSL certificate errors for '%@' will be ignored for the rest of this session.", hostname] delegate:nil 
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [newAlertView show];

        // Reload (now that we have added host to whitelist)
        [self loadURL:url];
    } else if ((alertView.tag == ALERTVIEW_EXTERN_PROTO)) {
        if (buttonIndex == 1) {
            // Warned user about opening URL in external app and they said it's OK.
            NSURL *navigationURL = objc_getAssociatedObject(alertView, &AlertViewExternProtoUrl);
            //NSLog(@"launching URL: %@", [navigationURL absoluteString]);
            [[UIApplication sharedApplication] openURL:navigationURL];
        } else {
            [self addressBarCancel];
        }
    } else if ((alertView.tag == ALERTVIEW_INCOMING_URL)) {
        if (buttonIndex == 1) {
            // Warned user about opening this incoming URL and they said it's OK.
            NSURL *navigationURL = objc_getAssociatedObject(alertView, &AlertViewIncomingUrl);
            //NSLog(@"launching URL: %@", [navigationURL absoluteString]);
            [self loadURL:navigationURL];
        } else {
            // Otherwise, open default homepage.
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            [self loadURL:[NSURL URLWithString:appDelegate.homepage]];
        }
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
                        options:UIViewAnimationOptionCurveEaseInOut
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
                        options:UIViewAnimationOptionCurveEaseInOut
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
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    if (![appDelegate.tor didFirstConnect]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Opening Bridge Configuration"
                                                        message:@"This configuration is for advanced Tor users. It *may* help if you are having trouble getting past the initial \"Connecting...\" step.\n\nPlease visit the following link in another browser for instructions:\n\nhttp://onionbrowser.com/help/"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        
        BridgeTableViewController *bridgesVC = [[BridgeTableViewController alloc] initWithStyle:UITableViewStylePlain];
        [bridgesVC setManagedObjectContext:[appDelegate managedObjectContext]];
        
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bridgesVC];
        navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [self presentViewController:navController animated:YES completion:nil];
    } else {
        [_optionsMenu showFromToolbar:_toolbar];
    }
}
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (actionSheet == _optionsMenu) {
        if (buttonIndex == 0) {
            ////////////////////////////////////////////////////////
            // New Identity
            ////////////////////////////////////////////////////////
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            [appDelegate.tor requestNewTorIdentity];
            
            [appDelegate wipeAppData];
            
            // Initialize a new UIWebView (to clear the history of the previous one)
            CGSize size = [UIScreen mainScreen].bounds.size;
            
            // Flip if we are rotated
            if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
                size = CGSizeMake(size.height, size.width);
            }
            
            NSString *reqSysVer = @"7.0";
            NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
            if (
                ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending) &&
                ([appDelegate deviceType] == X_DEVICE_IS_IPAD)
            ){
                // 7.0+, iPad, do nothing
            } else {
                size.height -= 20.0f;
            }
            size.height -= kToolBarHeight;
            size.height -= kNavBarHeight;
            
            CGRect webViewFrame = [[UIScreen mainScreen] applicationFrame];
            webViewFrame.origin.y = kNavBarHeight;
            webViewFrame.origin.x = 0;
            
            webViewFrame.size = size;
            
            UIWebView *newWebView = [[UIWebView alloc] initWithFrame:webViewFrame];
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
                                                            message:@"Requesting a new IP address from Tor. Cache, cookies, and browser history cleared.\n\nDue to an iOS limitation, visisted links still get the ':visited' CSS highlight state. iOS is resistant to script-based access to this information, but if you are still concerned about leaking history, please force-quit this app and re-launch.\n\nFor more details:\nhttp://yu8.in/M5"
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK" 
                                                  otherButtonTitles:nil];
            [alert show];
        } else if (buttonIndex == 1) {
            ////////////////////////////////////////////////////////
            // Add To Bookmarks
            ////////////////////////////////////////////////////////
            [self addCurrentAsBookmark];
        } else if (buttonIndex == 2) {
            ////////////////////////////////////////////////////////
            // Settings Menu
            ////////////////////////////////////////////////////////
            SettingsViewController *settingsController = [[SettingsViewController alloc] initWithNibName:@"SettingsViewController" bundle:nil];
            [self presentViewController:settingsController animated:YES completion:nil];
        }
        
        if ((buttonIndex == 0) || (buttonIndex == 3)) {
            ////////////////////////////////////////////////////////
            // New Identity OR Return To Home
            ////////////////////////////////////////////////////////
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            [self loadURL:[NSURL URLWithString:appDelegate.homepage]];
        } else if (buttonIndex == 4) {
            ////////////////////////////////////////////////////////
            // About Page
            ////////////////////////////////////////////////////////
            [self loadURL:[NSURL URLWithString:@"onionbrowser:about"]];
        } else if (buttonIndex == 5) {
            ////////////////////////////////////////////////////////
            // Help Page
            ////////////////////////////////////////////////////////
            [self loadURL:[NSURL URLWithString:@"onionbrowser:help"]];
        }
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
    if (!_addressField.isEditing) {
        _addressField.text = _currentURL;
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
    if (_myWebView.loading) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        _stopRefreshButton = nil;
        _stopRefreshButton = [[UIBarButtonItem alloc]
                              initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                              target:self
                              action:@selector(stopLoading)];
    } else {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        _stopRefreshButton = nil;
        _stopRefreshButton = [[UIBarButtonItem alloc]
                              initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                              target:self
                              action:@selector(reload)];
    }
    _stopRefreshButton.enabled = YES;
    NSMutableArray *items = [[NSMutableArray alloc] init];
    UIBarButtonItem *space = [[UIBarButtonItem alloc]
                              initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                              target:nil
                              action:nil];
    [items addObject:_backButton];
    [items addObject:space];
    [items addObject:_forwardButton];
    [items addObject:space];
    [items addObject:_toolButton];
    [items addObject:space];
    [items addObject:_bookmarkButton];
    [items addObject:space];
    [items addObject:_stopRefreshButton];
    [_toolbar setItems:items animated:NO];

}

- (void)updateTitle:(UIWebView*)aWebView
{
    NSString* pageTitle = [aWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
    
    /* if iOS < 7.0 */
    NSString *reqSysVer = @"7.0";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    if ([currSysVer compare:reqSysVer options:NSNumericSearch] == NSOrderedAscending) {
        _pageTitleLabel.text = pageTitle;
    }
    /* endif */
}

- (void)updateAddress:(NSURLRequest*)request {
    NSURL* url = [request mainDocumentURL];
    NSString* absoluteString;
    
    if ((url != nil) && [[url scheme] isEqualToString:@"file"]) {
        // Faked local URLs
        if ([[url absoluteString] rangeOfString:@"startup.html"].location != NSNotFound) {
            absoluteString = @"onionbrowser:start";
        }
        else if ([[url absoluteString] rangeOfString:@"about.html"].location != NSNotFound) {
            absoluteString = @"onionbrowser:about";
        } else {
            absoluteString = @"";
        }
    } else {
        // Regular ol' web URL.
        absoluteString = [url absoluteString];
    }
    
    if (![absoluteString isEqualToString:_currentURL]){
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

- (void) addCurrentAsBookmark {
    if ((_currentURL != nil) && ![_currentURL isEqualToString:@""]) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bookmark" inManagedObjectContext:appDelegate.managedObjectContext];
        [request setEntity:entity];
        
        NSError *error = nil;
        NSUInteger numBookmarks = [appDelegate.managedObjectContext countForFetchRequest:request error:&error];
        if (error) {
            // error state?
        }
        Bookmark *bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:appDelegate.managedObjectContext];
        
        NSString *pageTitle = [_myWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
        [bookmark setTitle:pageTitle];
        [bookmark setUrl:_currentURL];
        [bookmark setOrder:numBookmarks];
        
        NSError *saveError = nil;
        if (![appDelegate.managedObjectContext save:&saveError]) {
            NSLog(@"Error saving bookmark: %@", saveError);
        }

        UIAlertView* alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Add Bookmark"
                                  message:[NSString stringWithFormat:@"Added '%@' %@ to bookmarks.",
                                           pageTitle, _currentURL]
                                  delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        alertView.delegate = self;
        [alertView show];
    } else {
        UIAlertView* alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Add Bookmark"
                                  message:@"Can't bookmark a (local) page with no URL."
                                  delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        alertView.delegate = self;
        [alertView show];
    }
}

-(void)showBookmarks {
    BookmarkTableViewController *bookmarksVC = [[BookmarkTableViewController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController *bookmarkNavController = [[UINavigationController alloc]
                                                     initWithRootViewController:bookmarksVC];
    
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
    NSManagedObjectContext *context = [appDelegate managedObjectContext];
    
    bookmarksVC.managedObjectContext = context;
    
    [self presentViewController:bookmarkNavController animated:YES completion:nil];
}

#pragma mark - NJKWebViewProgressDelegate
-(void)webViewProgress:(NJKWebViewProgress *)webViewProgress updateProgress:(float)progress
{
    [_progressView setProgress:progress animated:YES];
    self.title = [_myWebView stringByEvaluatingJavaScriptFromString:@"document.title"];
}

@end
