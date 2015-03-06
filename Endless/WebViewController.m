#import "AppDelegate.h"
#import "URLInterceptor.h"
#import "WebViewController.h"
#import "WebViewTab.h"
#import "WebViewMenuController.h"
#import "WYPopoverController.h"

#define STATUSBAR_HEIGHT 20
#define TOOLBAR_HEIGHT 46
#define TOOLBAR_PADDING 6
#define TOOLBAR_BUTTON_SIZE 30

@implementation WebViewController {
	AppDelegate *appDelegate;

	UIScrollView *tabScroller;
	UIPageControl *tabChooser;
	int curTabIndex;
	NSMutableArray *webViewTabs;
	
	UIView *toolbar;
	UITextField *urlField;
	UIImageView *lockIcon;
	UIImageView *brokenLockIcon;
	UIImageView *blankIcon;
	UIProgressView *progressBar;
	UIToolbar *tabToolbar;
	UILabel *tabCount;
	
	UIButton *backButton;
	UIButton *forwardButton;
	UIButton *tabsButton;
	UIButton *settingsButton;
	
	UIBarButtonItem *tabAddButton;
	UIBarButtonItem *tabDoneButton;
	
	float lastWebViewScrollOffset;
	CGRect origTabScrollerFrame;
	BOOL showingTabs;
	BOOL webViewScrollIsDecelerating;
	BOOL webViewScrollIsDragging;
	
	WYPopoverController *popover;
}

- (void)loadView
{
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate setWebViewController:self];
	
	UIWebView *twv = [[UIWebView alloc] initWithFrame:CGRectZero];
	[appDelegate setDefaultUserAgent:[twv stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"]];
	twv = nil;
	
	webViewTabs = [[NSMutableArray alloc] initWithCapacity:10];
	curTabIndex = 0;
	
	self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].applicationFrame.size.width, [UIScreen mainScreen].applicationFrame.size.height)];
	
	tabScroller = [[UIScrollView alloc] init];
	[tabScroller setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
	[[self view] addSubview:tabScroller];
	
	toolbar = [[UIView alloc] init];
	[toolbar setClipsToBounds:YES];
	[[self view] addSubview:toolbar];
	
	progressBar = [[UIProgressView alloc] init];
	[progressBar setTrackTintColor:[UIColor clearColor]];
	[progressBar setTintColor:self.view.window.tintColor];
	[progressBar setProgress:0.0];
	[toolbar addSubview:progressBar];
	
	backButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *backImage = [[UIImage imageNamed:@"back"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[backButton setImage:backImage forState:UIControlStateNormal];
	[backButton addTarget:self action:@selector(goBack:) forControlEvents:UIControlEventTouchUpInside];
	[toolbar addSubview:backButton];
	
	forwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *forwardImage = [[UIImage imageNamed:@"forward"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[forwardButton setImage:forwardImage forState:UIControlStateNormal];
	[forwardButton addTarget:self action:@selector(goForward:) forControlEvents:UIControlEventTouchUpInside];
	[toolbar addSubview:forwardButton];
	
	urlField = [[UITextField alloc] init];
	[urlField setBorderStyle:UITextBorderStyleRoundedRect];
	[urlField setKeyboardType:UIKeyboardTypeWebSearch];
	[urlField setFont:[UIFont systemFontOfSize:15]];
	[urlField setReturnKeyType:UIReturnKeyGo];
	[urlField setClearButtonMode:UITextFieldViewModeWhileEditing];
	[urlField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
	[urlField setLeftViewMode:UITextFieldViewModeAlways];
	[urlField setSpellCheckingType:UITextSpellCheckingTypeNo];
	[urlField setDelegate:self];
	[toolbar addSubview:urlField];
	
	lockIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"lock"]];
	[lockIcon setFrame:CGRectMake(0, 0, 24, 16)];
	[lockIcon setContentMode:UIViewContentModeScaleAspectFit];
	
	brokenLockIcon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"broken_lock"]];
	[brokenLockIcon setFrame:CGRectMake(0, 0, 24, 16)];
	[brokenLockIcon setContentMode:UIViewContentModeScaleAspectFit];
	
	blankIcon = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 24, 16)];
	[urlField setLeftView:blankIcon];
	
	tabsButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *tabsImage = [[UIImage imageNamed:@"tabs"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[tabsButton setImage:tabsImage forState:UIControlStateNormal];
	[tabsButton setTintColor:[progressBar tintColor]];
	[tabsButton addTarget:self action:@selector(showTabs:) forControlEvents:UIControlEventTouchUpInside];
	[toolbar addSubview:tabsButton];
	
	tabCount = [[UILabel alloc] init];
	[tabCount setText:@""];
	[tabCount setTextAlignment:NSTextAlignmentCenter];
	[tabCount setFont:[UIFont systemFontOfSize:11]];
	[tabCount setTextColor:[progressBar tintColor]];
	[toolbar addSubview:tabCount];
	
	settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *settingsImage = [[UIImage imageNamed:@"settings"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[settingsButton setImage:settingsImage forState:UIControlStateNormal];
	[settingsButton setTintColor:[progressBar tintColor]];
	[settingsButton addTarget:self action:@selector(showPopover:) forControlEvents:UIControlEventTouchUpInside];
	[toolbar addSubview:settingsButton];
	
	[tabScroller setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
	[tabScroller setAutoresizesSubviews:NO];
	[tabScroller setShowsHorizontalScrollIndicator:NO];
	[tabScroller setShowsVerticalScrollIndicator:NO];
	[tabScroller setScrollsToTop:NO];
	[tabScroller setDelaysContentTouches:NO];
	[tabScroller setDelegate:self];

	tabChooser = [[UIPageControl alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - TOOLBAR_HEIGHT - 12, self.view.bounds.size.width, TOOLBAR_HEIGHT)];
	[tabChooser setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin)];
	[tabChooser addTarget:self action:@selector(slideToCurrentTab:) forControlEvents:UIControlEventValueChanged];
	[tabChooser setPageIndicatorTintColor:[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0]];
	[tabChooser setCurrentPageIndicatorTintColor:[UIColor grayColor]];
	[tabChooser setNumberOfPages:0];
	[self.view insertSubview:tabChooser aboveSubview:toolbar];
	[tabChooser setHidden:true];
	
	tabToolbar = [[UIToolbar alloc] init];
	[tabToolbar setClipsToBounds:YES];
	[tabToolbar setBarTintColor:[UIColor groupTableViewBackgroundColor]];
	[tabToolbar setHidden:true];
	[self.view insertSubview:tabToolbar aboveSubview:toolbar];
	
	tabAddButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addNewTabFromToolbar:)];
	tabDoneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneWithTabsButton:)];
	tabDoneButton.title = @"Done";

	tabToolbar.items = [NSArray arrayWithObjects:
			    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
			    tabAddButton,
			    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
			    tabDoneButton,
			    nil];
	
	[self adjustLayoutToSize:CGSizeMake(self.view.bounds.size.width, self.view.bounds.size.height)];
	
	[self updateSearchBarDetails];
	
	[self.view.window makeKeyAndVisible];
}

- (BOOL)prefersStatusBarHidden
{
	return NO;
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
	[super encodeRestorableStateWithCoder:coder];
	
	NSMutableArray *wvtd = [[NSMutableArray alloc] initWithCapacity:webViewTabs.count - 1];
	for (WebViewTab *wvt in webViewTabs) {
		if (wvt.url == nil)
			continue;
		
		[wvtd addObject:@{ @"url" : wvt.url, @"title" : wvt.title.text }];
		[[wvt webView] setRestorationIdentifier:[wvt.url absoluteString]];
		
#ifdef TRACE
		NSLog(@"encoded restoration state for tab %@ with %@", wvt.tabIndex, wvtd[wvtd.count - 1]);
#endif
	}
	[coder encodeObject:wvtd forKey:@"webViewTabs"];
	[coder encodeObject:[NSNumber numberWithLong:curTabIndex] forKey:@"curTabIndex"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
	[super decodeRestorableStateWithCoder:coder];

	NSMutableArray *wvt = [coder decodeObjectForKey:@"webViewTabs"];
	for (int i = 0; i < wvt.count; i++) {
		NSDictionary *params = wvt[i];
#ifdef TRACE
		NSLog(@"restoring tab %d with %@", i, params);
#endif
		WebViewTab *wvt = [self addNewTabForURL:[params objectForKey:@"url"] forRestoration:YES withCompletionBlock:nil];
		[[wvt title] setText:[params objectForKey:@"title"]];
	}
	
	NSNumber *cp = [coder decodeObjectForKey:@"curTabIndex"];
	if (cp != nil) {
		[self setCurTabIndex:[cp intValue]];
		[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:tabChooser.currentPage].origin.x, 0) animated:NO];
		
		/* wait for the UI to catch up */
		[[self curWebViewTab] performSelector:@selector(refresh) withObject:nil afterDelay:0.5];
	}
	
	[self updateSearchBarDetails];
}

- (void)viewDidAppear:(BOOL)animated
{
	if (webViewTabs.count == 0) {
		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
		NSDictionary *se = [[appDelegate searchEngines] objectForKey:[userDefaults stringForKey:@"search_engine"]];

		[self addNewTabForURL:[NSURL URLWithString:[se objectForKey:@"homepage_url"]]];
	}
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
	
	[coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
		if (showingTabs) {
			/* not sure why, but the transition looks nicer to do these linearly rather than adjusting layout in a completion block to ending tab showing */
			[self showTabsWithCompletionBlock:nil];
		}
	} completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
		[self adjustLayoutToSize:size];
	}];
}

- (void)adjustLayoutToSize:(CGSize)size
{
	self.view.frame = CGRectMake(0, 0, size.width, size.height);
	float y = ((TOOLBAR_HEIGHT - TOOLBAR_BUTTON_SIZE) / 2);
	
	toolbar.frame = tabToolbar.frame = CGRectMake(0, STATUSBAR_HEIGHT, size.width, TOOLBAR_HEIGHT);
	backButton.frame = CGRectMake(TOOLBAR_PADDING, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
	forwardButton.frame = CGRectMake(backButton.frame.origin.x + backButton.frame.size.width + TOOLBAR_PADDING, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
	
	settingsButton.frame = CGRectMake(size.width - backButton.frame.size.width - TOOLBAR_PADDING, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
	tabsButton.frame = CGRectMake(settingsButton.frame.origin.x - backButton.frame.size.width - TOOLBAR_PADDING, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
	tabCount.frame = CGRectMake(tabsButton.frame.origin.x + 6, tabsButton.frame.origin.y + 12, 14, 10);
	urlField.frame = [self frameForUrlField];
	
	progressBar.frame = CGRectMake(0, toolbar.frame.size.height - 2, toolbar.frame.size.width, 2);
	tabChooser.frame = CGRectMake(0, size.height - 24, size.width, 24);
	tabScroller.frame = CGRectMake(0, 0, size.width, size.height);

	for (int i = 0; i < webViewTabs.count; i++) {
		WebViewTab *wvt = webViewTabs[i];
		[wvt updateFrame:[self frameForTabIndex:i withSize:CGSizeMake(size.width, size.height - STATUSBAR_HEIGHT)]];
	}
	
	tabScroller.contentSize = CGSizeMake(size.width * tabChooser.numberOfPages, size.height);
	[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0) animated:NO];
	
	[self.view setNeedsDisplay];
}
- (CGRect)frameForTabIndex:(NSUInteger)number
{
	return [self frameForTabIndex:number withSize:CGSizeMake(0, 0)];
}

- (CGRect)frameForTabIndex:(NSUInteger)number withSize:(CGSize)size
{
	float screenWidth = size.width, screenHeight = size.height;
 
	if (size.width == 0) {
		screenWidth = [UIScreen mainScreen].applicationFrame.size.width;
		screenHeight = [UIScreen mainScreen].applicationFrame.size.height;
	}
	
	return CGRectMake((screenWidth * number), TOOLBAR_HEIGHT + STATUSBAR_HEIGHT, screenWidth, screenHeight - TOOLBAR_HEIGHT);
}

- (CGRect)frameForUrlField
{
	float x = forwardButton.frame.origin.x + forwardButton.frame.size.width + TOOLBAR_PADDING;
	float y = (TOOLBAR_HEIGHT - tabsButton.frame.size.height) / 2;
	float w = tabsButton.frame.origin.x - TOOLBAR_PADDING - forwardButton.frame.origin.x - forwardButton.frame.size.width - TOOLBAR_PADDING;
	float h = tabsButton.frame.size.height;
	
	if (backButton.hidden || [urlField isFirstResponder]) {
		x -= backButton.frame.size.width + TOOLBAR_PADDING;
		w += backButton.frame.size.width + TOOLBAR_PADDING;
	}
	
	if (forwardButton.hidden || [urlField isFirstResponder]) {
		x -= forwardButton.frame.size.width + TOOLBAR_PADDING;
		w += forwardButton.frame.size.width + TOOLBAR_PADDING;
	}
	
	return CGRectMake(x, y, w, h);
}

- (NSMutableArray *)webViewTabs
{
	return webViewTabs;
}

- (__strong WebViewTab *)curWebViewTab
{
	if (webViewTabs.count > 0) {
		return webViewTabs[curTabIndex];
	}
	else {
		return nil;
	}
}

- (void)setCurTabIndex:(int)tab
{
	if (curTabIndex == tab)
		return;
	
	curTabIndex = tab;
	tabChooser.currentPage = tab;
	
	for (int i = 0; i < webViewTabs.count; i++) {
		WebViewTab *wvt = [webViewTabs objectAtIndex:i];
		[[[wvt webView] scrollView] setScrollsToTop:(i == tab)];
	}
	
	if ([[self curWebViewTab] needsRefresh]) {
		[[self curWebViewTab] refresh];
	}
}

- (WebViewTab *)addNewTabForURL:(NSURL *)url
{
	return [self addNewTabForURL:url forRestoration:NO withCompletionBlock:nil];
}

- (WebViewTab *)addNewTabForURL:(NSURL *)url forRestoration:(BOOL)restoration withCompletionBlock:(void(^)(BOOL))block
{
	WebViewTab *wvt = [[WebViewTab alloc] initWithFrame:[self frameForTabIndex:webViewTabs.count] withRestorationIdentifier:(restoration ? [url absoluteString] : nil)];
	[wvt.webView.scrollView setDelegate:self];
	
	[webViewTabs addObject:wvt];
	[tabChooser setNumberOfPages:webViewTabs.count];
	[wvt setTabIndex:[NSNumber numberWithLong:(webViewTabs.count - 1)]];
	
	[tabCount setText:[NSString stringWithFormat:@"%lu", tabChooser.numberOfPages]];

	[tabScroller setContentSize:CGSizeMake(wvt.viewHolder.frame.size.width * tabChooser.numberOfPages, wvt.viewHolder.frame.size.height)];
	[tabScroller addSubview:wvt.viewHolder];
	
	[tabScroller bringSubviewToFront:toolbar];

	if (showingTabs)
		[wvt zoomOut];
	
	void (^swapToTab)(BOOL) = ^(BOOL finished) {
		[self setCurTabIndex:webViewTabs.count - 1];
		
		[self slideToCurrentTabWithCompletionBlock:^(BOOL finished) {
			if (url != nil)
				[wvt loadURL:url];

			[self showTabsWithCompletionBlock:block];
		}];
	};
	
	if (!restoration) {
		/* animate zooming out (if not already), switching to the new tab, then zoom back in */
		if (showingTabs) {
			swapToTab(YES);
		}
		else if (webViewTabs.count > 1) {
			[self showTabsWithCompletionBlock:swapToTab];
		}
		else if (url != nil) {
			[wvt loadURL:url];
		}
	}

	return wvt;
}

- (void)addNewTabFromToolbar:(id)_id
{
	[self addNewTabForURL:nil forRestoration:NO withCompletionBlock:^(BOOL finished) {
		[urlField becomeFirstResponder];
	}];
}

- (void)removeTab:(NSNumber *)tabNumber
{
	[self removeTab:tabNumber andFocusTab:[NSNumber numberWithInt:-1]];
}

- (void)removeTab:(NSNumber *)tabNumber andFocusTab:(NSNumber *)toFocus
{
	WebViewTab *wvt = (WebViewTab *)webViewTabs[tabNumber.intValue];
	
#ifdef TRACE
	NSLog(@"removing tab %@ (%@)", tabNumber, wvt.title.text);
#endif
	int futureFocusNumber = toFocus.intValue;
	if (futureFocusNumber > -1) {
		if (futureFocusNumber == tabNumber.intValue) {
			futureFocusNumber = -1;
		}
		else if (futureFocusNumber > tabNumber.intValue) {
			futureFocusNumber--;
		}
	}
	
	long wvtHash = [wvt hash];
	[[wvt viewHolder] removeFromSuperview];
	[webViewTabs removeObjectAtIndex:tabNumber.intValue];
	[wvt close];
	wvt = nil;
	
	[[appDelegate cookieJar] clearNonWhitelistedDataForTab:wvtHash];

	[tabChooser setNumberOfPages:webViewTabs.count];
	[tabCount setText:[NSString stringWithFormat:@"%lu", tabChooser.numberOfPages]];

	if (futureFocusNumber == -1) {
		if (curTabIndex == tabNumber.intValue) {
			if (webViewTabs.count > tabNumber.intValue && webViewTabs[tabNumber.intValue]) {
				/* keep currentPage pointing at the page that shifted down to here */
			}
			else if (tabNumber.intValue > 0 && webViewTabs[tabNumber.intValue - 1]) {
				/* removed last tab, keep the previous one */
				[self setCurTabIndex:tabNumber.intValue - 1];
			}
			else {
				/* no tabs left, add one and zoom out */
				[self addNewTabForURL:nil];
				[urlField becomeFirstResponder];
				return;
			}
		}
	}
	else {
		[self setCurTabIndex:futureFocusNumber];
	}
	
	[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
		tabScroller.contentSize = CGSizeMake(self.view.frame.size.width * tabChooser.numberOfPages, self.view.frame.size.height);

		for (int i = 0; i < webViewTabs.count; i++) {
			WebViewTab *wvt = webViewTabs[i];
			
			wvt.viewHolder.transform = CGAffineTransformMakeScale(1.0, 1.0);
			wvt.viewHolder.frame = [self frameForTabIndex:i];
			wvt.viewHolder.transform = CGAffineTransformMakeScale(ZOOM_OUT_SCALE, ZOOM_OUT_SCALE);
		}
	} completion:^(BOOL finished) {
		[self setCurTabIndex:curTabIndex];

		[self slideToCurrentTabWithCompletionBlock:^(BOOL finished) {
			showingTabs = true;
			[self showTabs:nil];
		}];
	}];
}

- (void)updateSearchBarDetails
{
	/* TODO: cache curURL and only do anything here if it changed, these changes might be expensive */

	if (urlField.isFirstResponder) {
		/* focused, don't muck with the URL while it's being edited */
		[urlField setTextAlignment:NSTextAlignmentNatural];
		[urlField setTextColor:[UIColor darkTextColor]];
		[urlField setLeftView:nil];
	}
	else {
		[urlField setTextAlignment:NSTextAlignmentCenter];
		[urlField setTextColor:[UIColor darkTextColor]];
		
		BOOL isEV = NO;
		if (self.curWebViewTab && self.curWebViewTab.secureMode >= WebViewTabSecureModeSecure) {
			[urlField setLeftView:lockIcon];
			
			if (self.curWebViewTab.secureMode == WebViewTabSecureModeSecureEV) {
				/* wait until the page is done loading */
				if ([progressBar progress] >= 1.0) {
					[urlField setTextColor:[UIColor colorWithRed:0 green:(183.0/255.0) blue:(82.0/255.0) alpha:1.0]];
			
					[urlField setText:self.curWebViewTab.evOrgName];
					isEV = YES;
				}
			}
		}
		else if (self.curWebViewTab && self.curWebViewTab.secureMode == WebViewTabSecureModeMixed) {
			[urlField setLeftView:brokenLockIcon];
		}
		else {
			[urlField setLeftView:nil];
		}
			
		if (!isEV) {
			NSString *host;
			if (self.curWebViewTab.url == nil)
				host = @"";
			else {
				host = [self.curWebViewTab.url host];
				if (host == nil)
					host = [self.curWebViewTab.url absoluteString];
			}
			
			NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^www\\d*\\." options:NSRegularExpressionCaseInsensitive error:nil];
			NSString *hostNoWWW = [regex stringByReplacingMatchesInString:host options:0 range:NSMakeRange(0, [host length]) withTemplate:@""];
			
			[urlField setTextColor:[UIColor darkTextColor]];
			[urlField setText:hostNoWWW];
			
			if ([urlField.text isEqualToString:@""]) {
				[urlField setTextAlignment:NSTextAlignmentLeft];
			}
		}
	}
	
	backButton.enabled = (self.curWebViewTab && self.curWebViewTab.canGoBack);
	[backButton setTintColor:(backButton.enabled ? [progressBar tintColor] : [UIColor grayColor])];

	forwardButton.hidden = !(self.curWebViewTab && self.curWebViewTab.canGoForward);
	[forwardButton setTintColor:(forwardButton.enabled ? [progressBar tintColor] : [UIColor grayColor])];

	[urlField setFrame:[self frameForUrlField]];
}

- (void)updateProgress
{
	BOOL animated = YES;
	float fadeAnimationDuration = 0.15;
	float fadeOutDelay = 0.3;

	float progress = [[[self curWebViewTab] progress] floatValue];
	if (progressBar.progress == progress) {
		return;
	}
	else if (progress == 0.0) {
		/* reset without animation, an actual update is probably coming right after this */
		progressBar.progress = 0.0;
		return;
	}
	
#ifdef TRACE
	NSLog(@"[Tab %@] loading progress of %@ at %f", self.curWebViewTab.tabIndex, [self.curWebViewTab.url absoluteString], progress);
#endif

	[self updateSearchBarDetails];
	
	if (progress >= 1.0) {
		[progressBar setProgress:progress animated:NO];

		[UIView animateWithDuration:fadeAnimationDuration delay:fadeOutDelay options:UIViewAnimationOptionCurveLinear animations:^{
			progressBar.alpha = 0.0;
		} completion:^(BOOL finished) {
			[self updateSearchBarDetails];
		}];
	}
	else {
		[UIView animateWithDuration:(animated ? fadeAnimationDuration : 0.0) delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
			[progressBar setProgress:progress animated:YES];

			if (showingTabs)
				progressBar.alpha = 0.0;
			else
				progressBar.alpha = 1.0;
		} completion:nil];
	}
}

- (void)webViewTouched
{
	if ([urlField isFirstResponder]) {
		[urlField resignFirstResponder];
	}
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	if (textField != urlField)
		return;

#ifdef TRACE
	NSLog(@"started editing");
#endif
	[urlField setText:[self.curWebViewTab.url absoluteString]];
	
	[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
		[urlField setTextAlignment:NSTextAlignmentNatural];
		[backButton setHidden:true];
		[forwardButton setHidden:true];
		[urlField setFrame:[self frameForUrlField]];
	} completion:^(BOOL finished) {
		[urlField performSelector:@selector(selectAll:) withObject:nil afterDelay:0.0];
	}];

	[self updateSearchBarDetails];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	if (textField != urlField)
		return;

#ifdef TRACE
	NSLog(@"ended editing with: %@", [textField text]);
#endif
	
	[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
		[urlField setTextAlignment:NSTextAlignmentCenter];
		[backButton setHidden:false];
		[forwardButton setHidden:!(self.curWebViewTab && self.curWebViewTab.canGoForward)];
		[urlField setFrame:[self frameForUrlField]];
	} completion:nil];

	[self updateSearchBarDetails];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if (textField != urlField) {
		return YES;
	}
	
	/* user is shifting to a new place, probably a good time to clear old data */
	[[appDelegate cookieJar] clearAllOldNonWhitelistedData];
	
	NSURL *enteredURL = [NSURL URLWithString:urlField.text];
	
	if (![enteredURL scheme] || [[enteredURL scheme] isEqualToString:@""]) {
		/* no scheme so if it has a space or no dots, assume it's a search query */
		if ([urlField.text containsString:@" "] || ![urlField.text containsString:@"."]) {
			NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
			NSDictionary *se = [[appDelegate searchEngines] objectForKey:[userDefaults stringForKey:@"search_engine"]];
			
			enteredURL = [NSURL URLWithString:[[NSString stringWithFormat:[se objectForKey:@"search_url"], urlField.text] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		}
		else {
			enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", urlField.text]];
		}
		
#ifdef TRACE
		NSLog(@"typed URL transformed to %@", enteredURL);
#endif
	}
	
	[urlField resignFirstResponder]; /* will unfocus and call textFieldDidEndEditing */

	[[self curWebViewTab] loadURL:enteredURL];
	
	return NO;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	if (scrollView != tabScroller)
		return;
	
	int page = round(scrollView.contentOffset.x / scrollView.frame.size.width);
	if (page < 0) {
		page = 0;
	}
	else if (page > tabChooser.numberOfPages) {
		page = (int)tabChooser.numberOfPages;
	}
	[self setCurTabIndex:page];
}

- (void)goBack:(id)_id
{
	[self.curWebViewTab goBack];
}

- (void)goForward:(id)_id
{
	[self.curWebViewTab goForward];
}

- (void)refresh
{
	[[self curWebViewTab] refresh];
}

- (void)forceRefresh
{
	[[self curWebViewTab] forceRefresh];
}

- (void)showPopover:(id)_id
{
	popover = [[WYPopoverController alloc] initWithContentViewController:[[WebViewMenuController alloc] init]];
	[popover setDelegate:self];
	
	[popover beginThemeUpdates];
	[popover setTheme:[WYPopoverTheme themeForIOS7]];
	[popover.theme setDimsBackgroundViewsTintColor:NO];
	[popover.theme setOuterCornerRadius:4];
	[popover.theme setOuterShadowBlurRadius:8];
	[popover.theme setOuterShadowColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.75]];
	[popover.theme setOuterShadowOffset:CGSizeMake(0, 2)];
	[popover.theme setOverlayColor:[UIColor clearColor]];
	[popover endThemeUpdates];
	
	[popover presentPopoverFromRect:CGRectMake(settingsButton.frame.origin.x, settingsButton.frame.origin.y + settingsButton.frame.size.height - 15, settingsButton.frame.size.width, settingsButton.frame.size.height) inView:self.view permittedArrowDirections:WYPopoverArrowDirectionAny animated:YES options:WYPopoverAnimationOptionFadeWithScale];
}

- (void)dismissPopover
{
	[popover dismissPopoverAnimated:YES];
}

- (BOOL)popoverControllerShouldDismissPopover:(WYPopoverController *)controller
{
	return YES;
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[URLInterceptor setSendDNT:[userDefaults boolForKey:@"send_dnt"]];
	[URLInterceptor setBlockIntoLocalNets:[userDefaults boolForKey:@"block_into_local_nets"]];
	[[appDelegate cookieJar] setOldDataSweepTimeout:[NSNumber numberWithInteger:[userDefaults integerForKey:@"old_data_sweep_mins"]]];
}

- (void)showTabs:(id)_id
{
	return [self showTabsWithCompletionBlock:nil];
}

- (void)showTabsWithCompletionBlock:(void(^)(BOOL))block
{
	if (showingTabs == false) {
		/* zoom out */
		
		/* make sure no text is selected */
		[urlField resignFirstResponder];
		
		origTabScrollerFrame = tabScroller.frame;
		
		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < webViewTabs.count; i++) {
				[(WebViewTab *)webViewTabs[i] zoomOut];
			}
			
			tabChooser.hidden = false;
			toolbar.hidden = true;
			tabToolbar.hidden = false;
			progressBar.alpha = 0.0;
			
			tabScroller.frame = CGRectMake(tabScroller.frame.origin.x, 0, tabScroller.frame.size.width, tabScroller.frame.size.height);
		} completion:block];
		
		tabScroller.contentOffset = CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0);
		tabScroller.scrollEnabled = YES;
		tabScroller.pagingEnabled = YES;
		
		UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedOnWebViewTab:)];
		singleTapGestureRecognizer.numberOfTapsRequired = 1;
		singleTapGestureRecognizer.enabled = YES;
		singleTapGestureRecognizer.cancelsTouchesInView = NO;
		[tabScroller addGestureRecognizer:singleTapGestureRecognizer];
	}
	else {
		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < webViewTabs.count; i++) {
				[(WebViewTab *)webViewTabs[i] zoomNormal];
			}
			
			tabChooser.hidden = true;
			toolbar.hidden = false;
			tabToolbar.hidden = true;
			progressBar.alpha = (progressBar.progress > 0.0 && progressBar.progress < 1.0 ? 1.0 : 0.0);
			tabScroller.frame = origTabScrollerFrame;
		} completion:block];

		tabScroller.scrollEnabled = NO;
		tabScroller.pagingEnabled = NO;
		
		[self updateSearchBarDetails];
	}
	
	showingTabs = !showingTabs;
}

- (void)doneWithTabsButton:(id)_id
{
	[self showTabs:nil];
}

- (void)tappedOnWebViewTab:(UITapGestureRecognizer *)gesture
{
	if (!showingTabs) {
		if ([urlField isFirstResponder]) {
			[urlField resignFirstResponder];
		}
		
		return;
	}
	
	CGPoint point = [gesture locationInView:self.curWebViewTab.viewHolder];
	
	/* fuzz a bit to make it easier to tap */
	int fuzz = 8;
	CGRect closerFrame = CGRectMake(self.curWebViewTab.closer.frame.origin.x - fuzz, self.curWebViewTab.closer.frame.origin.y - fuzz, self.curWebViewTab.closer.frame.size.width + (fuzz * 2), self.curWebViewTab.closer.frame.size.width + (fuzz * 2));
	if (CGRectContainsPoint(closerFrame, point)) {
		[self removeTab:[NSNumber numberWithLong:curTabIndex]];
	}
	else {
		[self showTabs:nil];
	}
}

- (void)slideToCurrentTabWithCompletionBlock:(void(^)(BOOL))block
{
	[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0) animated:NO];
	} completion:block];
}

- (IBAction)slideToCurrentTab:(id)_id
{
	[self slideToCurrentTabWithCompletionBlock:nil];
}

@end
