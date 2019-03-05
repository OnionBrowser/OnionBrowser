/*
 * Endless
 * Copyright (c) 2014-2018 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import "SSLCertificate.h"

#define ZOOM_OUT_SCALE 0.8
#define ZOOM_OUT_SCALE_ROTATED 0.7

#define HISTORY_SIZE 40

#define UNIVERSAL_LINKS_WORKAROUND_KEY @"yayprivacy"

typedef NS_ENUM(NSInteger, WebViewTabSecureMode) {
	WebViewTabSecureModeInsecure,
	WebViewTabSecureModeMixed,
	WebViewTabSecureModeSecure,
	WebViewTabSecureModeSecureEV,
};

static const struct keyboard_map_entry {
	char *input;
	int keycode;
	int keypress_keycode;
	int shift_keycode;
	int shift_keypress_keycode;
} keyboard_map[] = {
	{ "UIKeyInputEscape", 27, 0, 0 },

	{ "`", 192, '`', '~' },
	{ "1", '1', '1', '!' },
	{ "2", '2', '2', '@' },
	{ "3", '3', '3', '#' },
	{ "4", '4', '4', '$' },
	{ "5", '5', '5', '%' },
	{ "6", '6', '6', '^' },
	{ "7", '7', '7', '&' },
	{ "8", '8', '8', '*' },
	{ "9", '9', '9', '(' },
	{ "0", '0', '0', ')' },
	{ "-", 189, '-', '_' },
	{ "=", 187, '=', '+' },
	{ "\b", 8, 0, 0 },
	
	{ "\t", 9, 0, 0 },
	{ "q", 'Q', 'q', 'Q' },
	{ "w", 'W', 'w', 'W' },
	{ "e", 'E', 'e', 'E' },
	{ "r", 'R', 'r', 'R' },
	{ "t", 'T', 't', 'T' },
	{ "y", 'Y', 'y', 'Y' },
	{ "u", 'U', 'u', 'U' },
	{ "i", 'I', 'i', 'I' },
	{ "o", 'O', 'o', 'O' },
	{ "p", 'P', 'p', 'P' },
	{ "[", 219, '[', '{' },
	{ "]", 221, ']', '}' },
	{ "\\", 220, '\\', '|' },

	{ "a", 'A', 'a', 'A' },
	{ "s", 'S', 's', 'S' },
	{ "d", 'D', 'd', 'D' },
	{ "f", 'F', 'f', 'F' },
	{ "g", 'G', 'g', 'G' },
	{ "h", 'H', 'h', 'H' },
	{ "j", 'J', 'j', 'J' },
	{ "k", 'K', 'k', 'K' },
	{ "l", 'L', 'l', 'L' },
	{ ";", 186, ';', ':' },
	{ "'", 222, '\'', '"' },
	{ "\r", 13, 0, 0 },

	{ "z", 'Z', 'z', 'Z' },
	{ "x", 'X', 'x', 'X' },
	{ "c", 'C', 'c', 'C' },
	{ "v", 'V', 'v', 'V' },
	{ "b", 'B', 'b', 'B' },
	{ "n", 'N', 'n', 'N' },
	{ "m", 'M', 'm', 'M' },
	{ ",", 188, ',', '<' },
	{ ".", 190, '.', '>' },
	{ "/", 191, '/', '/' },
	
	{ " ", ' ', ' ', ' ' },
	{ "UIKeyInputLeftArrow", 37, 0, 0 },
	{ "UIKeyInputUpArrow", 38, 0, 0 },
	{ "UIKeyInputRightArrow", 39, 0, 0 },
	{ "UIKeyInputDownArrow", 40, 0, 0 },

	{ NULL }
};

@interface WebViewTab : NSObject <UIWebViewDelegate, UIGestureRecognizerDelegate, UIActivityItemSource>

@property (strong, atomic) UIView *viewHolder;
@property (strong, atomic) UIWebView *webView;
@property (strong, atomic) UIRefreshControl *refresher;
@property (strong, atomic) NSURL *url;
@property BOOL needsRefresh;
@property (strong, atomic) NSNumber *tabIndex;
@property (strong, atomic) UIView *titleHolder;
@property (strong, atomic) UILabel *title;
@property (strong, atomic) UILabel *closer;
@property (strong, nonatomic) NSNumber *progress;
@property BOOL forcingRefresh;

@property WebViewTabSecureMode secureMode;
@property (strong, nonatomic) SSLCertificate *SSLCertificate;
@property NSMutableDictionary *applicableHTTPSEverywhereRules;
@property NSMutableDictionary *applicableURLBlockerTargets;

/* for javascript IPC */
@property (strong, atomic) NSString *randID;
@property (strong, atomic) NSNumber *openedByTabHash;

@property (strong, atomic) NSMutableArray *history;

+ (WebViewTab *)openedWebViewTabByRandID:(NSString *)randID;

- (id)initWithFrame:(CGRect)frame;
- (id)initWithFrame:(CGRect)frame withRestorationIdentifier:(NSString *)rid;
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
- (void)handleKeyCommand:(UIKeyCommand *)keyCommand;

@end
