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
#import "SettingsTableViewController.h"
#import "Bookmark.h"
#import "BridgeViewController.h"
#import "NJKWebViewProgressView.h"
#import "NSStringPunycodeAdditions.h"
#import <objc/runtime.h>

#define ALERTVIEW_SSL_WARNING 1
#define ALERTVIEW_EXTERN_PROTO 2
#define ALERTVIEW_INCOMING_URL 3
#define ALERTVIEW_TORFAIL 4

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
static const NSInteger kTLSSecurePadlockTag = 1004;
static const NSInteger kTLSInsecurePadlockTag = 1005;

static const Boolean kForwardButton = YES;
static const Boolean kBackwardButton = NO;

static char SSLWarningKey;

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
            torStatus = _torStatus,
            tlsStatus = _tlsStatus;


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
    UIWebView *loadingStatus = (UIWebView *)[self.view viewWithTag:kLoadingStatusTag];

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

    unsigned int fontsize = 12;
    NSString *margintop = @"1.5em";
    if (IS_IPHONE && ((unsigned long)[[UIScreen mainScreen] bounds].size.height < 568)) {
      //NSLog(@"iPhone 4");
      fontsize = 11;
    } else if (IS_IPHONE && ((unsigned long)[[UIScreen mainScreen] bounds].size.height >= 667) && ((unsigned long)[[UIScreen mainScreen] bounds].size.height < 736)) {
      //NSLog(@"iPhone 6");
      fontsize = 13;
      margintop = @"50px";
    } else if (IS_IPHONE && ((unsigned long)[[UIScreen mainScreen] bounds].size.height >= 736)) {
      //NSLog(@"iPhone 6+");
      fontsize = 15;
      margintop = @"50px";
    } else if (IS_IPAD) {
      //NSLog(@"iPad");
      fontsize = 20;
      margintop = @"80px";
    }
    //NSLog(@"%lu", (unsigned long)[[UIScreen mainScreen] bounds].size.height);

    NSString *status = [NSString stringWithFormat:@""
      "<html lang='en-us'><head><meta http-equiv='Content-Type' content='text/html; charset=utf-8'/><meta charset='utf-8' />"
      "<style type='text/css'>body{font:%upt Helvetica;line-height:1.35em;margin-top:%@} "
      "progress{background:#fff;border:0;height:18px;border-radius:9px;-webkit-appearance:none;appearance:none} "
      "p{margin-bottom:1.5em}</style>"
      "<meta name='viewport' content='width=300'/>"
      "</head><body><div style='margin:0 0.5em;padding:0.5em 1em;border-radius:1em;background:#fafafa;border:1px solid #000'>"
      "<p style='margin:0;padding:0;float:right;margin-top:0.5em;line-height:2em'>%@%%</p>"
      "<p style='margin-top:1em'><span style='font-size:2em;font-weight:bold'>Connecting…</span></p>"
      "<p>%@<br>"
      "<progress max='100' value='%@' style='width:100%%'></progress><br></p>"
      "<p>If this takes longer than a minute, please close and re-open the app.</p>"
      "<p>If your ISP blocks connections to Tor, you may configure bridges by  "
      "pressing the middle (settings) button at the bottom of the screen.</p>"
      "<p>If you continue to have issues, go to:<br><b>onionbrowser.com/help</b>"
      "</div></body></html>",
      fontsize,
      margintop,
      progress_str,
      summary_str,
      progress_str];

    //NSLog(@"%@", status);

    [loadingStatus loadHTMLString:[status description] baseURL:nil];
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
    NSString *urlProto = [[navigationURL scheme] lowercaseString];
    if ([urlProto isEqualToString:@"onionbrowser"]||[urlProto isEqualToString:@"onionbrowsers"]||[urlProto isEqualToString:@"about"]||[urlProto isEqualToString:@"http"]||[urlProto isEqualToString:@"https"]) {
        /***** One of our supported protocols *****/

        // Cancel any existing nav
        [_myWebView stopLoading];

        // Remove the "connecting..." (initial tor load) overlay if it still exists.
        UIView *loadingStatus = [self.view viewWithTag:kLoadingStatusTag];
        if (loadingStatus != nil) {
            [loadingStatus removeFromSuperview];
        }

        // Build request and go.
        _myWebView.scalesPageToFit = YES;
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:navigationURL];
        [req setHTTPShouldUsePipelining:YES];
        [_myWebView loadRequest:req];

        if ([urlProto isEqualToString:@"https"]) {
          [self updateTLSStatus:TLSSTATUS_YES];
        } else {
          [self updateTLSStatus:TLSSTATUS_NO];
        }

        _addressField.text = @"";
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

    _tlsStatus = TLSSTATUS_NO;

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
    size.height -= 20.0f;
    size.height -= kToolBarHeight;
    size.height -= kNavBarHeight;
    
    CGRect webViewFrame = [[UIScreen mainScreen] applicationFrame];
    webViewFrame.origin.y = kNavBarHeight;
    webViewFrame.origin.x = 0;
    webViewFrame.size = size;
    
    _myWebView = [[UIWebView alloc] initWithFrame:webViewFrame];
    //_myWebView.backgroundColor = [UIColor whiteColor];
    _myWebView.scalesPageToFit = YES;
    _myWebView.contentScaleFactor = 3;
    _myWebView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
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
    _optionsMenu = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [_optionsMenu addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [_optionsMenu addAction:[UIAlertAction actionWithTitle:@"New Identity" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self newIdentity];
    }]];
    [_optionsMenu addAction:[UIAlertAction actionWithTitle:@"Bookmark Current Page" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self addCurrentAsBookmark];
    }]];
    [_optionsMenu addAction:[UIAlertAction actionWithTitle:@"Browser Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self performSelector:@selector(openSettingsView) withObject: nil afterDelay: 0];
    }]];
    [_optionsMenu addAction:[UIAlertAction actionWithTitle:@"Open Home Page" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self goHome];
    }]];
    [_optionsMenu addAction:[UIAlertAction actionWithTitle:@"About Onion Browser" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self loadURL:[NSURL URLWithString:@"onionbrowser:about"]];
    }]];
    [_optionsMenu addAction:[UIAlertAction actionWithTitle:@"Help / Support" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self loadURL:[NSURL URLWithString:@"onionbrowser:help"]];
    }]];
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

    // add the "progress bar" to the view
    _progressProxy = [[NJKWebViewProgress alloc] init];
    _myWebView.delegate = _progressProxy;
    _progressProxy.webViewProxyDelegate = self;
    _progressProxy.progressDelegate = self;

    CGRect navBarBounds = navBar.bounds;
    CGFloat progressBarHeight = 2.f;
    CGRect barFrame = CGRectMake(0, navBarBounds.size.height - progressBarHeight, navBarBounds.size.width, progressBarHeight);
    _progressView = [[NJKWebViewProgressView alloc] initWithFrame:barFrame];
    _progressView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [_progressView setProgress:1.0f animated:NO];
    [navBar addSubview:_progressView];
    [navBar bringSubviewToFront:_progressView];

    [self.view addSubview:navBar];
    // (/navbar)
    
    // Since this is first load: set up the overlay "loading..." bit that
    // will display tor initialization status.
    CGRect screenFrame = [[UIScreen mainScreen] applicationFrame];
    UIWebView *loadingStatus = [[UIWebView alloc] initWithFrame:CGRectMake(0,
                                                                       kNavBarHeight,
                                                                       screenFrame.size.width,
                                                                       screenFrame.size.height-kNavBarHeight*2.0)];
    loadingStatus.opaque = NO;
    loadingStatus.backgroundColor = [UIColor clearColor];

    [loadingStatus setAutoresizingMask:UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleBottomMargin|UIViewAutoresizingFlexibleRightMargin];

    loadingStatus.tag = kLoadingStatusTag;
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
    [bookmark setTitle:@"Search: DuckDuckGo"];
    [bookmark setUrl:@"https://3g2upl4pq6kufc4m.onion/html/"];
    [bookmark setOrder:i++];

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"Search: DuckDuckGo (Plain HTTPS)"];
    [bookmark setUrl:@"https://duckduckgo.com/html/"];
    [bookmark setOrder:i++];

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"Search: StartPage.com"];
    [bookmark setUrl:@"https://startpage.com/m/"];
    [bookmark setOrder:i++];

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"IP Address Check"];
    [bookmark setUrl:@"https://duckduckgo.com/lite/?q=what+is+my+ip"];
    [bookmark setOrder:i++];

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"The Tor Project"];
    [bookmark setUrl:@"http://www.torproject.org/"];
    [bookmark setOrder:i++];

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"Tor Project Blog"];
    [bookmark setUrl:@"https://blog.torproject.org/"];
    [bookmark setOrder:i++];

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"Electronic Frontier Foundation"];
    [bookmark setUrl:@"https://www.eff.org/"];
    [bookmark setOrder:i++];

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"Freedom of the Press Foundation"];
    [bookmark setUrl:@"https://freedom.press/"];
    [bookmark setOrder:i++];

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"Tactical Technology Collective"];
    [bookmark setUrl:@"https://tacticaltech.org/"];
    [bookmark setOrder:i++];

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"ProPublica.org (.onion)"];
    [bookmark setUrl:@"http://propub3r6espa33w.onion/"];
    [bookmark setOrder:i++];

    bookmark = (Bookmark *)[NSEntityDescription insertNewObjectForEntityForName:@"Bookmark" inManagedObjectContext:context];
    [bookmark setTitle:@"Facebook (.onion)"];
    [bookmark setUrl:@"https://m.facebookcorewwwi.onion/"];
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
    if ([[[[request URL] scheme] lowercaseString] isEqualToString:@"data"]) {
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
    [self updateTitle:webView];
    NSURLRequest* request = [webView request];
    [self updateAddress:request];
    [self informError:error];
    #ifdef DEBUG
        NSString* errorString = [NSString stringWithFormat:@"error %@",
                                 error.localizedDescription];
        NSLog(@"[WebViewController] Error: %@", errorString);
    #endif
}

- (void)informError:(NSError *)error {

    // Skip NSURLErrorDomain:kCFURLErrorCancelled because that's just "Cancel"
    // (user pressing stop button). Likewise with WebKitErrorFrameLoadInterrupted
    if (([error.domain isEqualToString:NSURLErrorDomain] && (error.code == kCFURLErrorCancelled))||
        (([error.domain isEqualToString:(NSString *)@"WebKitErrorDomain"]) && (error.code == 102))
       ){
      return;
    }


    if ([error.domain isEqualToString:NSPOSIXErrorDomain] && (error.code == 61)) {
        /* Tor died */

        #ifdef DEBUG
        NSLog(@"Tor socket failure: %@, %li --- %@ --- %@", error.domain, (long)error.code, error.localizedDescription, error.userInfo);
        #endif

        UIAlertView* alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Tor connection failure"
                                  message:@"Onion Browser lost connection to the Tor anonymity network and is unable to reconnect. This may occur if Onion Browser went to the background or if device went to sleep while Onion Browser was active.\n\nPlease quit the app and try again. If you need to bookmark the current page or save information from the current page, you may press 'Cancel' to remain in the app without network capability."
                                  delegate:nil
                                  cancelButtonTitle:@"Cancel"
                                  otherButtonTitles:@"Quit App",nil];
        alertView.delegate = self;
        alertView.tag = ALERTVIEW_TORFAIL;

        [alertView show];
    } else if ([error.domain isEqualToString:@"NSOSStatusErrorDomain"] &&
        (error.code == -9807 || error.code == -9812)) {
        /* INVALID CERT */
        // Invalid certificate chain; valid cert chain, untrusted root

        #ifdef DEBUG
        NSLog(@"Certificate error: %@, %li --- %@ --- %@", error.domain, (long)error.code, error.localizedDescription, error.userInfo);
        #endif

        NSURL *url = [error.userInfo objectForKey:NSURLErrorFailingURLErrorKey];
        NSURL *failingURL = [error.userInfo objectForKey:@"NSErrorFailingURLKey"];
        UIAlertView* alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Cannot Verify Website Identity"
                                  message:[NSString stringWithFormat:@"Either the SSL certificate for '%@' is self-signed or the certificate was signed by an untrusted authority.\n\nFor normal websites, it is generally unsafe to proceed.\n\nFor .onion websites (or sites using CACert or self-signed certificates), you may proceed if you think you can trust this website's URL.", url.host]
                                  delegate:nil
                                  cancelButtonTitle:@"Cancel"
                                  otherButtonTitles:@"Continue",nil];
        alertView.delegate = self;
        alertView.tag = ALERTVIEW_SSL_WARNING;

        objc_setAssociatedObject(alertView, &SSLWarningKey, failingURL, OBJC_ASSOCIATION_RETAIN);

        [alertView show];

    } else {
      // ALL other error types are just notices (so no Cancel vs Continue stuff)
      NSString* errorTitle;
      NSString* errorDescription;

      #ifdef DEBUG
      NSLog(@"Displayed Error: %@, %li --- %@ --- %@", error.domain, (long)error.code, error.localizedDescription, error.userInfo);
      #endif

      if ([error.domain isEqualToString:(NSString *)kCFErrorDomainCFNetwork] &&
               ([error.domain isEqualToString:@"NSOSStatusErrorDomain"] &&
               (error.code == -9800 || error.code == -9801 || error.code == -9809 || error.code == -9818))) {
        /* SSL/TLS ERROR */
        // https://www.opensource.apple.com/source/Security/Security-55179.13/libsecurity_ssl/Security/SecureTransport.h

        NSURL *url = [error.userInfo objectForKey:NSURLErrorFailingURLErrorKey];
        errorTitle = @"HTTPS Connection Failed";
        errorDescription = [NSString stringWithFormat:@"A secure connection to '%@' could not be made.\nThe site might be down, there could be a Tor network outage, or your 'minimum SSL/TLS' setting might want stronger security than the website provides.\n\nFull error: '%@'",
                                url.host, error.localizedDescription];

      } else if ([error.domain isEqualToString:NSURLErrorDomain]) {
          /* HTTP ERRORS */
          // https://www.opensource.apple.com/source/Security/Security-55179.13/libsecurity_ssl/Security/SecureTransport.h

          if (error.code == kCFURLErrorHTTPTooManyRedirects) {
              errorDescription = @"This website is stuck in a redirect loop. The web page you tried to access redirected you to another web page, which, in turn, is redirecting you (and so on).\n\nPlease contact the site operator to fix this problem.";
          } else if ((error.code == kCFURLErrorCannotFindHost) || (error.code == kCFURLErrorDNSLookupFailed)) {
              errorDescription = @"The website you tried to access could not be found.";
          } else if (error.code == kCFURLErrorResourceUnavailable) {
              errorDescription = @"The web page you tried to access is currently unavailable.";
          }
      } else if ([error.domain isEqualToString:(NSString *)@"WebKitErrorDomain"]) {
          if ((error.code == 100) || (error.code == 101)) {
              errorDescription = @"Onion Browser cannot display this type of content.";
          }
      } else if ([error.domain isEqualToString:(NSString *)kCFErrorDomainCFNetwork] ||
                 [error.domain isEqualToString:@"NSOSStatusErrorDomain"]) {
          if (error.code == kCFSOCKS5ErrorBadState) {
              errorDescription = @"Could not connect to the server. Either the domain name is incorrect, the server is inaccessible, or the Tor circuit was broken.";
          } else if (error.code == kCFHostErrorHostNotFound) {
              errorDescription = @"The website you tried to access could not be found.";
          }
      }

      // default
      if (errorTitle == nil) {
        errorTitle = @"Cannot Open Page";
      }
      if (errorDescription == nil) {
        errorDescription = [NSString stringWithFormat:@"An error occurred: %@\n(Error \"%@: %li)\"",
          error.localizedDescription, error.domain, (long)error.code];
      }

      UIAlertView* alertView = [[UIAlertView alloc]
        initWithTitle:errorTitle
        message:errorDescription
        delegate:nil
        cancelButtonTitle:@"OK"
        otherButtonTitles:nil];
      [alertView show];

    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if ((alertView.tag == ALERTVIEW_TORFAIL) && (buttonIndex == 1)) {
        // Tor failed, user says we can quit app.
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        [appDelegate wipeAppData];
        exit(0);
    }


    if ((alertView.tag == ALERTVIEW_SSL_WARNING) && (buttonIndex == 1)) {
        // "Continue anyway" for SSL cert error
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];

        // Assumung URL in address bar is the one that caused this error.
        NSURL *url = objc_getAssociatedObject(alertView, &SSLWarningKey);
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
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    textField.autocorrectionType = UITextAutocorrectionTypeNo;

    // Stop loading if we are loading a page
    [_myWebView stopLoading];
    
    [self hideTLSStatus];

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
    textField.autocorrectionType = UITextAutocorrectionTypeNo;

    UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];
    UIButton *cancelButton = (UIButton *)[self.view viewWithTag:kAddressCancelButtonTag];

    _addressField.clearButtonMode = UITextFieldViewModeNever;
    
    NSString *reqSysVer = @"7.0";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    CGRect addressFrame;
    CGRect labelFrame = CGRectMake(kMargin, kSpacer,
                                   navBar.bounds.size.width - 2*kMargin, kLabelHeight);
    if ([currSysVer compare:reqSysVer options:NSNumericSearch] == NSOrderedAscending) {
        /* if iOS < 7.0 */
        addressFrame = CGRectMake(kMargin, kSpacer*2.0 + kLabelHeight,
                                     labelFrame.size.width, kAddressHeight);
    } else {
        /*  iOS 7.0+ */
        addressFrame = CGRectMake(kMargin, kSpacer7*2.0 + kLabelHeight,
                                         labelFrame.size.width, kAddressHeight);
    }

    [UIView setAnimationsEnabled:YES];
    [UIView animateWithDuration:0.2
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         _addressField.frame = addressFrame;
                         [cancelButton setFrame:CGRectMake(navBar.bounds.size.width,
                                                           kSpacer*2.0 + kLabelHeight,
                                                           75 - kMargin,
                                                           kAddressHeight)];
                     }
                     completion:^(BOOL finished) {
                         [self updateTLSStatus:TLSSTATUS_PREVIOUS];
                         [cancelButton removeFromSuperview];
                     }]; 
}

# pragma mark -
# pragma mark Options Menu action sheet

- (void)openOptionsMenu {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    if (![appDelegate.tor didFirstConnect]) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Bridge Configuration"
                                                        message:@"You can configure bridges here if your ISP normally blocks access to Tor.\n\nIf you did not mean to access the Bridge configuration, press \"Cancel\", then \"Restart App\", and then re-launch Onion Browser."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        
        BridgeViewController *bridgesVC = [[BridgeViewController alloc] init];
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bridgesVC];
        navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [self presentViewController:navController animated:YES completion:nil];
    } else {
        [self presentViewController:_optionsMenu animated:YES completion:nil];
    }
}

- (void)newIdentity {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    [appDelegate.tor requestNewTorIdentity];

    [appDelegate wipeAppData];

    UIWebView *newWebView = [[UIWebView alloc] initWithFrame:[_myWebView frame]];
    //newWebView.backgroundColor = [UIColor whiteColor];
    newWebView.scalesPageToFit = YES;
    newWebView.contentScaleFactor = 3;
    newWebView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    newWebView.delegate = _progressProxy;
    [_myWebView removeFromSuperview];
    _myWebView = newWebView;
    [self.view addSubview: _myWebView];

    // Reset the address field
    _addressField.text = @"";

    // Reset forward/back buttons.
    [self updateButtons];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                    message:@"Requesting a new IP address from Tor. Cache, cookies, and browser history cleared.\n\nDue to an iOS limitation, visisted links still get the ':visited' CSS highlight state. iOS is resistant to script-based access to this information, but if you are still concerned about leaking history, please force-quit this app and re-launch.\n\nFor more details:\nhttp://yu8.in/M5"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK" 
                                          otherButtonTitles:nil];
    [alert show];
    [self goHome];
}
- (void) goHome {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    _addressField.text = @"";
    [self loadURL:[NSURL URLWithString:appDelegate.homepage]];
}
-(void)openSettingsView {
    SettingsTableViewController *settingsController = [[SettingsTableViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *settingsNavController = [[UINavigationController alloc]
                                                     initWithRootViewController:settingsController];
    
    [self presentViewController:settingsNavController animated:YES completion:nil];
}

# pragma mark -
# pragma mark Toolbar/navbar behavior

- (void)goForward {
    [_myWebView stopLoading];
    _addressField.text = @"";
    [_myWebView goForward];
    [self updateTitle:_myWebView];
    [self updateAddress:[_myWebView request]];
    [self updateButtons];
}
- (void)goBack {
    [_myWebView stopLoading];
    _addressField.text = @"";
    [_myWebView goBack];
    [self updateTitle:_myWebView];
    [self updateAddress:[_myWebView request]];
    [self updateButtons];
}
- (void)stopLoading {
    [_progressView setProgress:1.0f animated:NO];
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
        [_progressView setProgress:1.0f animated:NO];
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
    
    if ((url != nil) && [[[url scheme] lowercaseString] isEqualToString:@"file"]) {
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
    _addressField.text = [_addressField.text encodedURLString];

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

- (void)updateTLSStatus:(Byte)newStatus {
    if (newStatus != TLSSTATUS_PREVIOUS) {
      _tlsStatus = newStatus;
    }

    UIView *uivSecure = [self.view viewWithTag:kTLSSecurePadlockTag];
    if (uivSecure == nil) {
      NSString *imgpth = [[NSBundle mainBundle] pathForResource:@"secure.png" ofType:nil];
      uivSecure = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imgpth]];
      UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];

      uivSecure.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
      uivSecure.tag = kTLSSecurePadlockTag;
      uivSecure.frame = CGRectMake(kMargin + (navBar.bounds.size.width - 2*kMargin - 22), kSpacer * 2.0 + kLabelHeight*1.5, 18, 18);
      [navBar addSubview:uivSecure];
    }
    UIView *uivInsecure = [self.view viewWithTag:kTLSInsecurePadlockTag];
    if (uivInsecure == nil) {
      NSString *imgpth = [[NSBundle mainBundle] pathForResource:@"insecure.png" ofType:nil];
      uivInsecure = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imgpth]];
      UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];

      uivInsecure.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
      uivInsecure.tag = kTLSInsecurePadlockTag;
      uivInsecure.frame = CGRectMake(kMargin + (navBar.bounds.size.width - 2*kMargin - 22), kSpacer * 2.0 + kLabelHeight*1.5, 18, 18);
      [navBar addSubview:uivInsecure];
    }

    if (_tlsStatus == TLSSTATUS_NO) {
      [uivSecure setHidden:YES];
      [uivInsecure setHidden:YES];
    } else if (_tlsStatus == TLSSTATUS_YES) {
      [uivSecure setHidden:NO];
      [uivInsecure setHidden:YES];
    } else {
      [uivSecure setHidden:YES];
      [uivInsecure setHidden:NO];
    }
}

- (void)hideTLSStatus {
    UIView *uivSecure = [self.view viewWithTag:kTLSSecurePadlockTag];
    if (uivSecure == nil) {
      NSString *imgpth = [[NSBundle mainBundle] pathForResource:@"secure.png" ofType:nil];
      uivSecure = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imgpth]];
      UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];

      uivSecure.tag = kTLSSecurePadlockTag;
      uivSecure.frame = CGRectMake(kMargin + (navBar.bounds.size.width - 2*kMargin - 22), kSpacer * 2.0 + kLabelHeight*1.5, 18, 18);
      [navBar addSubview:uivSecure];
    }
    UIView *uivInsecure = [self.view viewWithTag:kTLSInsecurePadlockTag];
    if (uivInsecure == nil) {
      NSString *imgpth = [[NSBundle mainBundle] pathForResource:@"insecure.png" ofType:nil];
      uivInsecure = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:imgpth]];
      UINavigationBar *navBar = (UINavigationBar *)[self.view viewWithTag:kNavBarTag];

      uivInsecure.tag = kTLSInsecurePadlockTag;
      uivInsecure.frame = CGRectMake(kMargin + (navBar.bounds.size.width - 2*kMargin - 22), kSpacer * 2.0 + kLabelHeight*1.5, 18, 18);
      [navBar addSubview:uivInsecure];
    }

      [uivSecure setHidden:YES];
      [uivInsecure setHidden:YES];
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
