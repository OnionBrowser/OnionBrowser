/*
 * Endless
 * Copyright (c) 2014-2018 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "BookmarkController.h"
#import "HistoryController.h"
#import "SearchResultsController.h"
#import "SSLCertificateViewController.h"
#import "WebViewController.h"
#import "WebViewTab.h"
#import "WebViewMenuController.h"
#import "WYPopoverController.h"

#import "IASKSettingsReader.h"

@implementation WebViewController {
	AppDelegate *appDelegate;
	UIView *wrapper;
	
	UIScrollView *tabScroller;
	UIPageControl *tabChooser;
	int curTabIndex;
	NSMutableArray <WebViewTab *> *webViewTabs;
	
	UIView *toolbar;
	UITextField *urlField;
	UIButton *lockIcon;
	UIButton *brokenLockIcon;
    UIColor *blueTint;
	UIProgressView *progressBar;
	UIView *tabToolbarHairline;
	UIToolbar *tabToolbar;
	UILabel *tabCount;
	int keyboardHeight;
	BOOL keyboardShowing;
	float safeAreaBottom;
	
	UIButton *backButton;
	UILongPressGestureRecognizer *historyRecognizer;
	UIButton *forwardButton;
	UIButton *tabsButton;
	UIButton *settingsButton;
	
	UIBarButtonItem *tabAddButton;
	UIBarButtonItem *tabDoneButton;
	
	float lastWebViewScrollOffset;
	BOOL showingTabs;
	BOOL webViewScrollIsDecelerating;
	BOOL webViewScrollIsDragging;
	
	WYPopoverController *popover;
	
	BookmarkController *bookmarks;
	SearchResultsController *searchResults;
}

- (void)loadView
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate setWebViewController:self];
	[appDelegate setDefaultUserAgent:[self buildDefaultUserAgent]];
	
	webViewTabs = [[NSMutableArray alloc] initWithCapacity:10];
	curTabIndex = 0;
	
	self.view = [[UIView alloc] initWithFrame:[[appDelegate window] frame]];
	
	wrapper = [[UIView alloc] initWithFrame:self.view.frame];
	[[self view] addSubview:wrapper];

	tabScroller = [[UIScrollView alloc] init];
	[tabScroller setScrollEnabled:NO];
	[wrapper addSubview:tabScroller];
	
	toolbar = [[UIView alloc] init];
	[toolbar setClipsToBounds:YES];
	[[self view] addSubview:toolbar];
	
	keyboardHeight = 0;
	safeAreaBottom = 0;
	
	tabToolbarHairline = [[UIView alloc] init];
	[toolbar addSubview:tabToolbarHairline];

    // Fix issue #115:
    // Generate default blue iOS tint color.
    // We need to set this hard instead of relying on
    // [appDelegate window].tintColor, since the accessibility feature "darken colors" actually
    // makes the default tint color the exact same color as the background color, which effectitvely
    // hides icons from the human eye.
    blueTint = [UIColor colorWithRed:0 green:0.47843137254902 blue:1 alpha:1];

	progressBar = [[UIProgressView alloc] init];
	[progressBar setTrackTintColor:[UIColor clearColor]];
	[progressBar setTintColor:blueTint];
	[progressBar setProgress:0.0];
	[toolbar addSubview:progressBar];
	
	backButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *backImage = [[UIImage imageNamed:@"back"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[backButton setImage:backImage forState:UIControlStateNormal];
	[backButton addTarget:self action:@selector(goBack:) forControlEvents:UIControlEventTouchUpInside];
	[toolbar addSubview:backButton];

	historyRecognizer = [[UILongPressGestureRecognizer alloc] init];
	[historyRecognizer addTarget:self action:@selector(showHistory:)];
	[backButton addGestureRecognizer:historyRecognizer];
	
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
	[urlField setAutocorrectionType:UITextAutocorrectionTypeNo];
	[urlField setAutocapitalizationType:UITextAutocapitalizationTypeNone];
	[urlField setDelegate:self];
	[urlField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
	[toolbar addSubview:urlField];
	
	lockIcon = [UIButton buttonWithType:UIButtonTypeCustom];
	[lockIcon setFrame:CGRectMake(0, 0, 24, 16)];
	[lockIcon setImage:[[UIImage imageNamed:@"lock"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateNormal];
	[[lockIcon imageView] setContentMode:UIViewContentModeScaleAspectFit];
	[lockIcon addTarget:self action:@selector(showSSLCertificate) forControlEvents:UIControlEventTouchUpInside];
	
	brokenLockIcon = [UIButton buttonWithType:UIButtonTypeCustom];
	[brokenLockIcon setFrame:CGRectMake(0, 0, 24, 16)];
	[brokenLockIcon setImage:[UIImage imageNamed:@"broken_lock"] forState:UIControlStateNormal];
	[[brokenLockIcon imageView] setContentMode:UIViewContentModeScaleAspectFit];
	[brokenLockIcon addTarget:self action:@selector(showSSLCertificate) forControlEvents:UIControlEventTouchUpInside];

	tabsButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *tabsImage = [[UIImage imageNamed:@"tabs"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[tabsButton setImage:tabsImage forState:UIControlStateNormal];
	[tabsButton setTintColor:blueTint];
	[tabsButton addTarget:self action:@selector(showTabs:) forControlEvents:UIControlEventTouchUpInside];
	[toolbar addSubview:tabsButton];
	
	tabCount = [[UILabel alloc] init];
	[tabCount setText:@""];
	[tabCount setTextAlignment:NSTextAlignmentCenter];
	[tabCount setFont:[UIFont systemFontOfSize:11]];
	[tabCount setTextColor:blueTint];
	[toolbar addSubview:tabCount];
	
	settingsButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *settingsImage = [[UIImage imageNamed:@"settings"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[settingsButton setImage:settingsImage forState:UIControlStateNormal];
	[settingsButton setTintColor:blueTint];
	[settingsButton addTarget:self action:@selector(showPopover:) forControlEvents:UIControlEventTouchUpInside];
	[toolbar addSubview:settingsButton];
	
	[tabScroller setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
	[tabScroller setAutoresizesSubviews:NO];
	[tabScroller setShowsHorizontalScrollIndicator:NO];
	[tabScroller setShowsVerticalScrollIndicator:NO];
	[tabScroller setScrollsToTop:NO];
	[tabScroller setDelaysContentTouches:NO];
	[tabScroller setDelegate:self];

	tabChooser = [[UIPageControl alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, TOOLBAR_HEIGHT)];
	[tabChooser setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin)];
	[tabChooser addTarget:self action:@selector(slideToCurrentTab:) forControlEvents:UIControlEventValueChanged];
	[tabChooser setNumberOfPages:0];
	[self.view insertSubview:tabChooser aboveSubview:toolbar];
	[tabChooser setHidden:true];
	
	tabToolbar = [[UIToolbar alloc] init];
	[tabToolbar setClipsToBounds:YES];
	[tabToolbar setHidden:true];
	/* make completely transparent */
	[tabToolbar setBackgroundImage:[UIImage new] forToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault];
	[tabToolbar setShadowImage:[UIImage new] forToolbarPosition:UIBarPositionAny];
	[self.view insertSubview:tabToolbar aboveSubview:toolbar];
	
	tabAddButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addNewTabFromToolbar:)];
	tabDoneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneWithTabsButton:)];
	tabDoneButton.title = NSLocalizedString(@"Done", nil);

	tabToolbar.items = [NSArray arrayWithObjects:
			    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
			    tabAddButton,
			    [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:nil],
			    tabDoneButton,
			    nil];
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	[center addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[center addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[center addObserver:self selector:@selector(settingStaged:) name:kIASKAppSettingChanged object:nil];

	[[appDelegate window] addSubview:self.view];

	[self updateSearchBarDetails];
	
	[self.view.window makeKeyAndVisible];
}

- (UIButton *)settingsButton
{
	return settingsButton;
}

- (BOOL)prefersStatusBarHidden
{
	return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
	return UIStatusBarStyleDefault;
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	
	NSLog(@"=============================");
	NSLog(@"didReceiveMemoryWarning");
	NSLog(@"=============================");
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
	[super encodeRestorableStateWithCoder:coder];
	
	NSMutableArray *wvtd = [[NSMutableArray alloc] initWithCapacity:MAX(webViewTabs.count - 1, 1)];
	for (WebViewTab *wvt in webViewTabs) {
		if (wvt.url == nil)
			continue;
		
		[wvtd addObject:@{ @"url" : wvt.url, @"title" : wvt.title.text }];
		[[wvt webView] setRestorationIdentifier:[wvt.url absoluteString]];
	}
	[coder encodeObject:wvtd forKey:@"webViewTabs"];
	[coder encodeObject:[NSNumber numberWithInt:curTabIndex] forKey:@"curTabIndex"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
	[super decodeRestorableStateWithCoder:coder];

	NSMutableArray *wvt = [coder decodeObjectForKey:@"webViewTabs"];
	for (int i = 0; i < wvt.count; i++) {
		NSDictionary *params = wvt[i];
#ifdef TRACE
		NSLog(@"[WebViewController] restoring tab %d with %@", i, params);
#endif
		WebViewTab *wvt = [self addNewTabForURL:[params objectForKey:@"url"] forRestoration:YES withAnimation:WebViewTabAnimationHidden withCompletionBlock:nil];
		[[wvt title] setText:[params objectForKey:@"title"]];
	}
	
	NSNumber *cp = [coder decodeObjectForKey:@"curTabIndex"];
	if (cp != nil) {
		if ([cp intValue] <= [webViewTabs count] - 1)
			[self setCurTabIndex:[cp intValue]];
		
		[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:tabChooser.currentPage].origin.x, 0) animated:NO];
		
		/* wait for the UI to catch up */
		[[self curWebViewTab] performSelector:@selector(refresh) withObject:nil afterDelay:0.5];
	}
	
	[self updateSearchBarDetails];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	/* we made it this far, remove lock on previous startup */
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[userDefaults removeObjectForKey:STATE_RESTORE_TRY_KEY];
	[userDefaults synchronize];
	
	if ([appDelegate urlToOpenAtLaunch]) {
		NSURL *u = [appDelegate urlToOpenAtLaunch];
		[appDelegate setUrlToOpenAtLaunch:nil];
		
		[self addNewTabForURL:u];
	}
}

/* called when we've become visible (possibly again, from app delegate applicationDidBecomeActive) */
- (void)viewIsVisible
{
	if (webViewTabs.count == 0) {
		if ([appDelegate areTesting]) {
			[self addNewTabForURL:nil];
		} else {
			NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
			NSString *homepage = [userDefaults stringForKey:@"homepage"];
			
			if (homepage == nil || [homepage isEqualToString:@""]) {
				//NSDictionary *se = [[appDelegate searchEngines] objectForKey:[userDefaults stringForKey:@"search_engine"]];
				//homepage = [se objectForKey:@"homepage_url"];
                homepage = @"http://3heens4xbedlj57xwcggjsdglot7e36p4rogy642xokemfo2duh6bbyd.onion/";
			}
			
			[self addNewTabForURL:[NSURL URLWithString:homepage]];
		}
	}
}

- (void)viewIsNoLongerVisible
{
	if ([urlField isFirstResponder]) {
		[self unfocusUrlField];
	}
}

- (void)keyboardWillShow:(NSNotification *)notification
{
	CGRect keyboardStart = [[[notification userInfo] objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue];
	CGRect keyboardEnd = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
	
	/* iOS 11.4 started sending additional UIKeyboardWillShowNotification notifications when the user taps on the URL bar when the keyboard is already up, so keyboardHeight ends up being 0 (because there is no change in FrameBegin->FrameEnd) and disappears.  Keep track of whether the keyboard is showing and ignore these duplicate events until we get a UIKeyboardWillHideNotification event. */
	if (keyboardStart.origin.y == keyboardEnd.origin.y && keyboardShowing)
		return;
	
	/* on devices with a bluetooth keyboard attached, both values should be the same for a 0 height */
	keyboardHeight = keyboardStart.origin.y - keyboardEnd.origin.y;

	keyboardShowing = (keyboardHeight > 0);
	
	[self viewDidLayoutSubviews];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
	keyboardHeight = 0;
	keyboardShowing = NO;
	[self viewDidLayoutSubviews];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
	[super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

	[coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
		if (self->showingTabs)
			[self showTabsWithCompletionBlock:nil];
		
		[self dismissPopover];
	} completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
		/* in case this doesn't get called automatically for some reason */
		[self viewDidLayoutSubviews];
	}];
}

- (void)viewSafeAreaInsetsDidChange
{
	[super viewSafeAreaInsetsDidChange];
	
	if (self.view.safeAreaInsets.bottom != 0)
		safeAreaBottom = self.view.safeAreaInsets.bottom;
}

- (void)viewDidLayoutSubviews
{
	float statusBarHeight = [[UIApplication sharedApplication] statusBarFrame].size.height;

	/* views are transforming and we may calculate things incorrectly here, so just ignore this request */
	if (showingTabs)
		return;
	
	/* keep the root view the size of the window minus the statusbar */
	self.view.frame = CGRectMake(0, statusBarHeight, [appDelegate window].bounds.size.width, [appDelegate window].bounds.size.height - statusBarHeight - keyboardHeight);
	wrapper.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height);
	
	/* keep tabScroller the size of the root frame minus the toolbar */
	toolbar.frame = tabToolbar.frame = CGRectMake(0, 0, self.view.bounds.size.width - self.view.safeAreaInsets.left + self.view.safeAreaInsets.right, TOOLBAR_HEIGHT);
	progressBar.frame = CGRectMake(0, TOOLBAR_HEIGHT - 2, toolbar.frame.size.width, 2);
	tabToolbarHairline.frame = CGRectMake(0, TOOLBAR_HEIGHT - 0.5, toolbar.frame.size.width, 0.5);

	tabScroller.frame = CGRectMake(0, TOOLBAR_HEIGHT, self.view.bounds.size.width, self.view.bounds.size.height - TOOLBAR_HEIGHT);

	tabChooser.frame = CGRectMake(0, self.view.bounds.size.height - 20 - (keyboardHeight ? 0 : safeAreaBottom), tabScroller.bounds.size.width, 20);

	[[appDelegate window] setBackgroundColor:[UIColor groupTableViewBackgroundColor]];

	[wrapper setBackgroundColor:[UIColor groupTableViewBackgroundColor]];

	[tabScroller setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
	[toolbar setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
	[urlField setBackgroundColor:[UIColor whiteColor]];
	[tabToolbarHairline setBackgroundColor:[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0]];

	[tabAddButton setTintColor:blueTint];
	[tabDoneButton setTintColor:blueTint];
	[settingsButton setTintColor:blueTint];
	[tabsButton setTintColor:blueTint];
	[tabCount setTextColor:blueTint];

	[tabChooser setPageIndicatorTintColor:[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0]];
	[tabChooser setCurrentPageIndicatorTintColor:[UIColor grayColor]];

	[self setNeedsStatusBarAppearanceUpdate];

	/* tabScroller.frame is now our actual webview viewing area */

	for (int i = 0; i < webViewTabs.count; i++) {
		WebViewTab *wvt = webViewTabs[i];
		[wvt updateFrame:[self frameForTabIndex:i]];
	}

	/* things relative to the toolbar */
	float y = ((TOOLBAR_HEIGHT - 1 - TOOLBAR_BUTTON_SIZE) / 2);

	tabScroller.contentSize = CGSizeMake(tabScroller.frame.size.width * tabChooser.numberOfPages, tabScroller.frame.size.height);
	[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:curTabIndex].origin.x, 0) animated:NO];
	
	backButton.frame = CGRectMake(TOOLBAR_PADDING, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
	forwardButton.frame = CGRectMake(backButton.frame.origin.x + backButton.frame.size.width + TOOLBAR_PADDING, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
	
	settingsButton.frame = CGRectMake(tabScroller.frame.size.width - backButton.frame.size.width - TOOLBAR_PADDING, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
	tabsButton.frame = CGRectMake(settingsButton.frame.origin.x - backButton.frame.size.width - TOOLBAR_PADDING, y, TOOLBAR_BUTTON_SIZE, TOOLBAR_BUTTON_SIZE);
	
	tabCount.frame = CGRectMake(tabsButton.frame.origin.x + 6, tabsButton.frame.origin.y + 12, 14, 10);
	urlField.frame = [self frameForUrlField];
	
	if (bookmarks) {
		bookmarks.view.frame = CGRectMake(0, toolbar.frame.origin.y + toolbar.bounds.size.height, self.view.bounds.size.width, self.view.bounds.size.height);
	}

	[self updateSearchBarDetails];
}

- (CGRect)frameForTabIndex:(NSUInteger)number
{
	return CGRectMake((self.view.frame.size.width * number), 0, self.view.frame.size.width - self.view.safeAreaInsets.left - self.view.safeAreaInsets.right, tabScroller.frame.size.height);
}

- (CGRect)frameForUrlField
{
	float x = forwardButton.frame.origin.x + forwardButton.frame.size.width + TOOLBAR_PADDING;
	float y = (TOOLBAR_HEIGHT - 1 - tabsButton.frame.size.height) / 2;
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

- (void)focusUrlField
{
	[urlField becomeFirstResponder];
}

- (void)unfocusUrlField
{
	/* will unfocus and call textFieldDidEndEditing */
	[urlField resignFirstResponder];
}

- (NSMutableArray *)webViewTabs
{
	return webViewTabs;
}

- (__strong WebViewTab *)curWebViewTab
{
	if (webViewTabs.count > 0)
		return webViewTabs[curTabIndex];
	else
		return nil;
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
	return [self addNewTabForURL:url forRestoration:NO withAnimation:WebViewTabAnimationDefault withCompletionBlock:nil];
}

- (WebViewTab *)addNewTabForURL:(NSURL *)url forRestoration:(BOOL)restoration withAnimation:(WebViewTabAnimation)animation withCompletionBlock:(void(^)(BOOL))block
{
	WebViewTab *wvt = [[WebViewTab alloc] initWithFrame:[self frameForTabIndex:webViewTabs.count] withRestorationIdentifier:(restoration ? [url absoluteString] : nil)];
	[wvt.webView.scrollView setDelegate:self];
	
	[webViewTabs addObject:wvt];
	[tabChooser setNumberOfPages:webViewTabs.count];
	[wvt setTabIndex:[NSNumber numberWithLong:(webViewTabs.count - 1)]];
	
	[tabCount setText:[NSString stringWithFormat:@"%lu", (long)tabChooser.numberOfPages]];

	[tabScroller setContentSize:CGSizeMake(wvt.viewHolder.frame.size.width * tabChooser.numberOfPages, wvt.viewHolder.frame.size.height)];
	[tabScroller addSubview:wvt.viewHolder];
	[tabScroller bringSubviewToFront:toolbar];

	void (^swapToTab)(BOOL) = ^(BOOL dummy) {
		[self setCurTabIndex:(int)self->webViewTabs.count - 1];
		
		[self slideToCurrentTabWithAnimation:animation completionBlock:^(BOOL finished) {
			if (url != nil)
				[wvt loadURL:url];

			[self showTabsWithCompletionBlock:block];
		}];
	};
	
	if (animation == WebViewTabAnimationHidden) {
		if (url != nil && !restoration)
			[wvt loadURL:url];
		if (block != nil)
			block(YES);
	} else {
		if (showingTabs) {
			swapToTab(YES);
		}
		else if (webViewTabs.count > 1) {
			[self showTabsWithCompletionBlock:swapToTab];
		}
		else {
			if (url != nil && !restoration)
				[wvt loadURL:url];

			if (block != nil)
				block(YES);
		}
	}

	return wvt;
}

- (void)addNewTabFromToolbar:(id)_id
{
	UITextField *urlField = self->urlField;

	[self addNewTabForURL:nil forRestoration:NO withAnimation:WebViewTabAnimationDefault withCompletionBlock:^(BOOL finished) {
		[urlField becomeFirstResponder];
	}];
}

- (void)switchToTab:(NSNumber *)tabNumber
{
	if ([tabNumber intValue] >= [[self webViewTabs] count])
		return;
	
	if ([tabNumber intValue] == curTabIndex)
		return;
	
	WebViewTab *t = [[self webViewTabs] objectAtIndex:[tabNumber intValue]];
	void (^swapToTab)(BOOL) = ^(BOOL finished) {
		[self setCurTabIndex:[[t tabIndex] intValue]];
		
		[self slideToCurrentTabWithAnimation:WebViewTabAnimationDefault completionBlock:^(BOOL finished) {
			[self showTabsWithCompletionBlock:nil];
		}];
	};

	if (showingTabs) {
		swapToTab(YES);
	}
	else if (webViewTabs.count > 1) {
		[self showTabsWithCompletionBlock:swapToTab];
	}
}

- (void)reindexTabs
{
	int i = 0;
	BOOL seencur = NO;
	
	for (WebViewTab *wvt in [self webViewTabs]) {
		if (!seencur && [[wvt tabIndex] intValue] == curTabIndex) {
			curTabIndex = i;
			seencur = YES;
		}
	
		[wvt setTabIndex:[NSNumber numberWithInt:i]];
	
		i++;
	}
}

- (void)removeTab:(NSNumber *)tabNumber
{
	[self removeTab:tabNumber andFocusTab:[NSNumber numberWithInt:-1]];
}

- (void)removeTab:(NSNumber *)tabNumber andFocusTab:(NSNumber *)toFocus
{
	if (tabNumber.intValue > [webViewTabs count] - 1)
		return;
	
	if ([urlField isFirstResponder]) {
		[self unfocusUrlField];
		return;
	}
	
	WebViewTab *wvt = (WebViewTab *)webViewTabs[tabNumber.intValue];
	
#ifdef TRACE
	NSLog(@"[WebViewController] removing tab %@ (%@) and focusing %@", tabNumber, wvt.title.text, toFocus);
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
	wvt = nil;
	
	[[appDelegate cookieJar] clearNonWhitelistedDataForTab:wvtHash];

	[tabChooser setNumberOfPages:webViewTabs.count];
	[tabCount setText:[NSString stringWithFormat:@"%lu", (long)tabChooser.numberOfPages]];

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
				[self reindexTabs];

				UITextField *urlField = self->urlField;

				[self addNewTabForURL:nil forRestoration:false withAnimation:WebViewTabAnimationDefault withCompletionBlock:^(BOOL finished) {
					[urlField becomeFirstResponder];
				}];
				return;
			}
		}
	}
	else {
		[self setCurTabIndex:futureFocusNumber];
	}
	
	[self reindexTabs];
	
	[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
		self->tabScroller.contentSize = CGSizeMake([self frameForTabIndex:0].size.width * self->tabChooser.numberOfPages, [self frameForTabIndex:0].size.height);

		for (int i = 0; i < self->webViewTabs.count; i++) {
			WebViewTab *wvt = self->webViewTabs[i];
			
			[[wvt viewHolder] setTransform:CGAffineTransformIdentity];
			[[wvt viewHolder] setFrame:[self frameForTabIndex:i]];
			
			BOOL rotated = (wvt.viewHolder.frame.size.width > wvt.viewHolder.frame.size.height);
			[wvt.viewHolder setTransform:CGAffineTransformMakeScale(rotated ? ZOOM_OUT_SCALE_ROTATED : ZOOM_OUT_SCALE, rotated ? ZOOM_OUT_SCALE_ROTATED : ZOOM_OUT_SCALE)];
		}
	} completion:^(BOOL finished) {
		[self setCurTabIndex:self->curTabIndex];

		[self slideToCurrentTabWithAnimation:WebViewTabAnimationDefault completionBlock:^(BOOL finished) {
			self->showingTabs = true;
			[self showTabs:nil];
		}];
	}];
}

- (void)removeAllTabs
{
	curTabIndex = 0;

	[webViewTabs removeAllObjects];
	[tabChooser setNumberOfPages:0];

	[self updateSearchBarDetails];
}

- (void)updateSearchBarDetails
{
	/* TODO: cache curURL and only do anything here if it changed, these changes might be expensive */

	[urlField setTextColor:[UIColor darkTextColor]];

	if (urlField.isFirstResponder) {
		/* focused, don't muck with the URL while it's being edited */
		[urlField setTextAlignment:NSTextAlignmentNatural];
		[urlField setLeftView:nil];
	}
	else {
		[urlField setTextAlignment:NSTextAlignmentCenter];
		if (self.curWebViewTab && self.curWebViewTab.secureMode >= WebViewTabSecureModeSecure) {
			[urlField setLeftView:lockIcon];
			
			if (self.curWebViewTab.secureMode == WebViewTabSecureModeSecureEV)
				[lockIcon setTintColor:[UIColor colorWithRed:0 green:(183.0/255.0) blue:(82.0/255.0) alpha:1.0]];
			else
				[lockIcon setTintColor:[UIColor blackColor]];
		}
		else if (self.curWebViewTab && self.curWebViewTab.secureMode == WebViewTabSecureModeMixed) {
			[urlField setLeftView:brokenLockIcon];
		}
		else {
			[urlField setLeftView:nil];
		}
		
		NSString *host;
		if (self.curWebViewTab.url == nil)
		{
		 	host = @"";
		}
		else {
			host = self.curWebViewTab.url.host;
			if (host == nil)
			{
				if ([self.curWebViewTab.url isEqual:
					 [NSBundle.mainBundle URLForResource:@"credits" withExtension:@"html"]])
				{
					host = ABOUT_ONION_BROWSER;
				}
				else {
					host = self.curWebViewTab.url.absoluteString;
				}
			}
		}
		
		NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^www\\d*\\." options:NSRegularExpressionCaseInsensitive error:nil];
		NSString *hostNoWWW = [regex stringByReplacingMatchesInString:host options:0 range:NSMakeRange(0, [host length]) withTemplate:@""];
		
		[urlField setText:hostNoWWW];
		
		if ([urlField.text isEqualToString:@""]) {
			[urlField setTextAlignment:NSTextAlignmentLeft];
		}
	}
	
	backButton.enabled = (self.curWebViewTab && self.curWebViewTab.canGoBack);
	if (backButton.enabled)
		[backButton setTintColor:blueTint];
	else
		[backButton setTintColor:[UIColor grayColor]];

	forwardButton.hidden = !(self.curWebViewTab && self.curWebViewTab.canGoForward);
	if (forwardButton.enabled)
		[forwardButton setTintColor:blueTint];
	else
		[forwardButton setTintColor:[UIColor grayColor]];

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
			self->progressBar.alpha = 0.0;
		} completion:^(BOOL finished) {
			[self updateSearchBarDetails];
		}];
	}
	else {
		[UIView animateWithDuration:(animated ? fadeAnimationDuration : 0.0) delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
			[self->progressBar setProgress:progress animated:YES];

			if (self->showingTabs)
				self->progressBar.alpha = 0.0;
			else
				self->progressBar.alpha = 1.0;
		} completion:nil];
	}
}

- (void)webViewTouched
{
	if ([urlField isFirstResponder]) {
		[self unfocusUrlField];
	}
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	if (textField != urlField)
		return;

#ifdef TRACE
	NSLog(@"[WebViewController] started editing");
#endif
	
	[urlField setText:[self.curWebViewTab.url absoluteString]];
	
	if (bookmarks == nil)
		[self showBookmarks];
	
	[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
		[self->urlField setTextAlignment:NSTextAlignmentNatural];
		[self->backButton setHidden:true];
		[self->forwardButton setHidden:true];
		[self->urlField setFrame:[self frameForUrlField]];
	} completion:^(BOOL finished) {
		[self->urlField performSelector:@selector(selectAll:) withObject:nil afterDelay:0.1];
	}];

	[self updateSearchBarDetails];
}

- (void)textFieldDidChange:(UITextField *)textField
{
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];

	if (textField != urlField)
		return;

	/* if it looks like we're typing a url, stop searching */
	if ([urlField text] == nil || [[urlField text] isEqualToString:@""] || [[urlField text] hasPrefix:@"http:"] || [[urlField text] hasPrefix:@"https:"] || ([[urlField text] containsString:@"."] && [userDefaults boolForKey:@"search_engine_stop_dot"])) {
		[self hideSearchResults];
		[self showBookmarks];
		return;
	}
	
	if (![userDefaults boolForKey:@"search_engine_live"])
		return;
	
	[self hideBookmarks];
	[self showSearchResultsForQuery:[urlField text]];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	if (textField != urlField)
		return;

#ifdef TRACE
	NSLog(@"[WebViewController] ended editing with: %@", [textField text]);
#endif
	[self hideBookmarks];
	[self hideSearchResults];

	[UIView animateWithDuration:0.15 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
		[self->urlField setTextAlignment:NSTextAlignmentCenter];
		[self->backButton setHidden:false];
		[self->forwardButton setHidden:!(self.curWebViewTab && self.curWebViewTab.canGoForward)];
		[self->urlField setFrame:[self frameForUrlField]];
	} completion:nil];

	[self updateSearchBarDetails];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	if (textField != urlField) {
		return YES;
	}
	
	[self prepareForNewURLFromString:urlField.text];
	
	return NO;
}

- (void)prepareForNewURLFromString:(NSString *)url
{
	/* user is shifting to a new place, probably a good time to clear old data */
	[[appDelegate cookieJar] clearAllOldNonWhitelistedData];
	
	NSURL *enteredURL = [NSURL URLWithString:url];
	
	/* for some reason NSURL thinks "example.com:9091" should be "example.com" as the scheme with no host, so fix up first */
	if ([enteredURL host] == nil && [enteredURL scheme] != nil && ![[enteredURL scheme] isEqualToString:@"about"] && [enteredURL resourceSpecifier] != nil)
		enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", url]];
	
	if (![enteredURL scheme] || [[enteredURL scheme] isEqualToString:@""]) {
		/* no scheme so if it has a space or no dots, assume it's a search query */
		if ([url containsString:@" "] || ![url containsString:@"."]) {
			[[self curWebViewTab] searchFor:url];
			enteredURL = nil;
		}
		else
			enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", url]];
	}
	
	[self unfocusUrlField];

	if (enteredURL != nil)
		[[self curWebViewTab] loadURL:enteredURL];
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

- (void)showHistory:(id)_id
{
	[historyRecognizer setEnabled:NO];
	
	if ([[[self curWebViewTab] history] count] > 1) {
		UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:[[HistoryController alloc] initForTab:[self curWebViewTab]]];
		[self presentViewController:navController animated:YES completion:nil];
	}
	
	[historyRecognizer setEnabled:YES];
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
	
	[popover presentPopoverFromRect:CGRectMake(settingsButton.frame.origin.x, toolbar.frame.origin.y + settingsButton.frame.origin.y + settingsButton.frame.size.height - 30, settingsButton.frame.size.width, settingsButton.frame.size.height) inView:self.view permittedArrowDirections:WYPopoverArrowDirectionAny animated:YES options:WYPopoverAnimationOptionFadeWithScale];
}

- (void)dismissPopover
{
	[popover dismissPopoverAnimated:YES];
}

- (BOOL)popoverControllerShouldDismissPopover:(WYPopoverController *)controller
{
	return YES;
}

- (void)settingStaged:(NSNotification *)notification
{
	NSString *prop = [[[notification userInfo] allKeys] firstObject];
		
	if ([prop isEqualToString:@"mute_with_switch"]) {
		[appDelegate adjustMuteSwitchBehavior];
	}
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[[appDelegate cookieJar] setOldDataSweepTimeout:[NSNumber numberWithInteger:[userDefaults integerForKey:@"old_data_sweep_mins"]]];
}

- (void)showTabs:(id)_id
{
	return [self showTabsWithCompletionBlock:nil];
}

- (void)showTabsWithCompletionBlock:(void(^)(BOOL))block
{
	if (showingTabs == false) {
		/* zoom out to show all tabs */
		
		/* make sure no text is selected */
		[self unfocusUrlField];
		
		[UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < self->webViewTabs.count; i++)
				[(WebViewTab *)self->webViewTabs[i] zoomOut];
			
			self->tabChooser.hidden = false;
			self->toolbar.hidden = true;
			self->tabToolbar.hidden = false;
			self->progressBar.alpha = 0.0;
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
		[UIView animateWithDuration:0.15 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < self->webViewTabs.count; i++)
				[(WebViewTab *)self->webViewTabs[i] zoomNormal];
			
			self->tabChooser.hidden = true;
			self->toolbar.hidden = false;
			self->tabToolbar.hidden = true;
			self->progressBar.alpha = (self->progressBar.progress > 0.0 && self->progressBar.progress < 1.0 ? 1.0 : 0.0);
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

- (void)showSSLCertificate
{
	if ([[self curWebViewTab] SSLCertificate] == nil)
		return;
	
	SSLCertificateViewController *scvc = [[SSLCertificateViewController alloc] initWithSSLCertificate:[[self curWebViewTab] SSLCertificate]];
	scvc.title = [[[self curWebViewTab] url] host];
	
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:scvc];
	[self presentViewController:navController animated:YES completion:nil];
}

- (void)tappedOnWebViewTab:(UITapGestureRecognizer *)gesture
{
	if (!showingTabs) {
		if ([urlField isFirstResponder]) {
			[self unfocusUrlField];
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

- (void)slideToCurrentTabWithAnimation:(WebViewTabAnimation)animation completionBlock:(void(^)(BOOL))block
{
	[self updateProgress];

	void (^moveBlock)(void) = ^{
		[self->tabScroller setContentOffset:CGPointMake([self frameForTabIndex:self->curTabIndex].origin.x, 0) animated:NO];
	};
	
	if (animation == WebViewTabAnimationQuick) {
		moveBlock();
		block(YES);
	} else
		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:moveBlock completion:block];
}

- (IBAction)slideToCurrentTab:(id)_id
{
	[self slideToCurrentTabWithAnimation:WebViewTabAnimationDefault completionBlock:nil];
}

- (NSString *)buildDefaultUserAgent
{
	/*
	 * Some sites do mobile detection by looking for Safari in the UA, so make us look like Mobile Safari
	 *
	 * from "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12H321"
	 * to   "Mozilla/5.0 (iPhone; CPU iPhone OS 8_4_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12H321 Safari/600.1.4"
	 */

	SILENCE_DEPRECATION_ON
	UIWebView *twv = [[UIWebView alloc] initWithFrame:CGRectZero];
	SILENCE_WARNINGS_OFF
	NSString *ua = [twv stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
	
	NSMutableArray *uapieces = [[NSMutableArray alloc] initWithArray:[ua componentsSeparatedByString:@" "]];
	NSString *uamobile = uapieces[uapieces.count - 1];
	
	/* assume safari major version will match ios major */
	NSArray *osv = [[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."];
	uapieces[uapieces.count - 1] = [NSString stringWithFormat:@"Version/%@.0", osv[0]];
	
	[uapieces addObject:uamobile];
	
	/* now tack on "Safari/XXX.X.X" from webkit version */
	for (id j in uapieces) {
		if ([(NSString *)j containsString:@"AppleWebKit/"]) {
			[uapieces addObject:[(NSString *)j stringByReplacingOccurrencesOfString:@"AppleWebKit" withString:@"Safari"]];
			break;
		}
	}

	return [uapieces componentsJoinedByString:@" "];
}

- (void)showBookmarks
{
	if (bookmarks)
		return;
	
	bookmarks = [[BookmarkController alloc] init];

	bookmarks.view.frame = CGRectMake(0, toolbar.frame.size.height + toolbar.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height);

	[self addChildViewController:bookmarks];
	[self.view insertSubview:[bookmarks view] belowSubview:toolbar];
}

- (void)hideBookmarks
{
	if (!bookmarks)
		return;
	
	[[bookmarks view] removeFromSuperview];
	[bookmarks removeFromParentViewController];
	bookmarks = nil;
}

- (void)showSearchResultsForQuery:(NSString *)query
{
	if (!searchResults) {
		searchResults = [[SearchResultsController alloc] init];
	
		searchResults.view.frame = CGRectMake(0, toolbar.frame.size.height + toolbar.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height);
		
		[self addChildViewController:searchResults];
		[self.view insertSubview:[searchResults view] belowSubview:toolbar];
	}
	
	[searchResults updateSearchResultsForQuery:query];
}

- (void)hideSearchResults
{
	if (!searchResults)
		return;
	
	[[searchResults view] removeFromSuperview];
	[searchResults removeFromParentViewController];
	searchResults = nil;
}

@end
