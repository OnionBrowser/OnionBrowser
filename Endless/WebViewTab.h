/*
 * Endless
 * Copyright (c) 2014-2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SSLCertificate.h"

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
@property BOOL needsRefresh;
@property (strong, atomic) NSNumber *tabIndex;
@property (strong, atomic) UIView *titleHolder;
@property (strong, atomic) UILabel *title;
@property (strong, atomic) UILabel *closer;
@property (strong, nonatomic) NSNumber *progress;

@property WebViewTabSecureMode secureMode;
@property (strong, nonatomic) SSLCertificate *SSLCertificate;
@property NSMutableDictionary *applicableHTTPSEverywhereRules;

/* for javascript IPC */
@property (strong, atomic) NSString *randID;
@property (strong, atomic) NSNumber *openedByTabHash;

+ (WebViewTab *)openedWebViewTabByRandID:(NSString *)randID;

- (id)initWithFrame:(CGRect)frame;
- (id)initWithFrame:(CGRect)frame withRestorationIdentifier:(NSString *)rid;
- (void)close;
- (void)updateFrame:(CGRect)frame;
- (void)loadURL:(NSURL *)u;
- (void)searchFor:(NSString *)query;
- (BOOL)canGoBack;
- (BOOL)canGoForward;
- (void)goBack;
- (void)goForward;
- (void)refresh;
- (void)forceRefresh;
- (void)zoomOut;
- (void)zoomNormal;

@end
