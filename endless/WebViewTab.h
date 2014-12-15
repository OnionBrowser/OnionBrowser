#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "WebViewController.h"

#define ZOOM_OUT_SCALE 0.8

@interface WebViewTab : NSObject <UIWebViewDelegate, UIGestureRecognizerDelegate>

@property WebViewController *controller;

@property (strong, atomic) UIView *viewHolder;
@property (strong, atomic) UIWebView *webView;
@property (strong, atomic) NSURL *url;
@property (strong, atomic) NSNumber *tabNumber;
@property (strong, atomic) UIView *titleHolder;
@property (strong, atomic) UILabel *title;
@property (strong, atomic) UILabel *closer;

- (id)initWithFrame:(CGRect)frame controller:(WebViewController *)wvc;
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
