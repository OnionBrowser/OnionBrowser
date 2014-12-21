#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define ZOOM_OUT_SCALE 0.8

typedef NS_ENUM(NSInteger, WebViewTabSecureMode) {
	WebViewTabSecureModeInsecure,
	WebViewTabSecureModeMixed,
	WebViewTabSecureModeSecure,
	WebViewTabSecureModeSecureEV,
};

@interface WebViewTab : NSObject <UIWebViewDelegate, UIGestureRecognizerDelegate>

@property (strong, atomic) UIView *viewHolder;
@property (strong, atomic) UIWebView *webView;
@property (strong, atomic) NSURL *url;
@property (strong, atomic) NSNumber *tabNumber;
@property (strong, atomic) UIView *titleHolder;
@property (strong, atomic) UILabel *title;
@property (strong, atomic) UILabel *closer;

@property WebViewTabSecureMode secureMode;
@property (strong, atomic) NSString *evOrgName;

/* for javascript IPC */
@property (strong, atomic) NSString *randID;

+ (NSString *)javascriptToInject;
+ (WebViewTab *)openedWebViewTabByRandID:(NSString *)randID;

- (id)initWithFrame:(CGRect)frame;
- (void)updateFrame:(CGRect)frame;
- (float)progress;
- (void)loadURL:(NSURL *)u;
- (BOOL)canGoBack;
- (BOOL)canGoForward;
- (void)goBack;
- (void)goForward;
- (void)zoomOut;
- (void)zoomNormal;

@end
