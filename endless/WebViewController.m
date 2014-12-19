#import "AppDelegate.h"
#import "CookieWhitelistController.h"
#import "IASKAppSettingsViewController.h"
#import "URLInterceptor.h"
#import "WebViewController.h"
#import "WebViewTab.h"

#define STATUSBAR_HEIGHT 20
#define TOOLBAR_HEIGHT 44

@implementation WebViewController {
	UIScrollView *tabScroller;
	UIPageControl *tabChooser;
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

	AppDelegate *appDelegate;
	
	IASKAppSettingsViewController *appSettingsViewController;
	
	float lastWebViewScrollOffset;
	CGRect origTabScrollerFrame;
	BOOL showingTabs;
	BOOL webViewScrollIsDecelerating;
	BOOL webViewScrollIsDragging;
}

- (void)loadView
{
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate setWebViewController:self];
	
	webViewTabs = [[NSMutableArray alloc] initWithCapacity:10];

	self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].applicationFrame.size.width, [UIScreen mainScreen].applicationFrame.size.height)];
	
	tabScroller = [[UIScrollView alloc] init];
	[tabScroller setBackgroundColor:[UIColor groupTableViewBackgroundColor]];
	[[self view] addSubview:tabScroller];
	
	toolbar = [[UIView alloc] init];
	[toolbar setClipsToBounds:YES];
	[self.view addSubview:toolbar];
	
	progressBar = [[UIProgressView alloc] init];
	[progressBar setTrackTintColor:[UIColor clearColor]];
	[progressBar setTintColor:self.view.window.tintColor];
	[progressBar setProgress:0.0];
	[toolbar addSubview:progressBar];
	
	backButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *backImage = [[UIImage imageNamed:@"back"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[backButton setImage:backImage forState:UIControlStateNormal];
	[backButton setTintColor:[progressBar tintColor]];
	[backButton addTarget:self action:@selector(goBack:) forControlEvents:UIControlEventTouchUpInside];
	[toolbar addSubview:backButton];
	
	forwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
	UIImage *forwardImage = [[UIImage imageNamed:@"forward"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
	[forwardButton setImage:forwardImage forState:UIControlStateNormal];
	[forwardButton setTintColor:[progressBar tintColor]];
	[forwardButton addTarget:self action:@selector(goForward:) forControlEvents:UIControlEventTouchUpInside];
	[toolbar addSubview:forwardButton];
	
	urlField = [[UITextField alloc] init];
	[urlField setBorderStyle:UITextBorderStyleRoundedRect];
	[urlField setKeyboardType:UIKeyboardTypeURL];
	[urlField setFont:[UIFont systemFontOfSize:15]];
	[urlField setReturnKeyType:UIReturnKeyDone];
	[urlField setClearButtonMode:UITextFieldViewModeWhileEditing];
	[urlField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
	[urlField setLeftViewMode:UITextFieldViewModeAlways];
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
	[settingsButton addTarget:self action:@selector(showSettings:) forControlEvents:UIControlEventTouchUpInside];
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

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
	[self adjustLayoutToSize:size];
}

- (void)viewDidAppear:(BOOL)animated
{
	if (webViewTabs.count == 0) {
		NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
		NSDictionary *se = [[appDelegate searchEngines] objectForKey:[userDefaults stringForKey:@"search_engine"]];

		[self addNewTabForURL:[NSURL URLWithString:[se objectForKey:@"homepage_url"]]];
	}
}

- (void)adjustLayoutToSize:(CGSize)size
{
	self.view.frame = CGRectMake(0, 0, size.width, size.height);
	
	toolbar.frame = CGRectMake(0, STATUSBAR_HEIGHT, size.width, TOOLBAR_HEIGHT);
	
	backButton.frame = CGRectMake(8, 8, 30, 30);
	forwardButton.frame = CGRectMake(backButton.frame.origin.x + backButton.frame.size.width + 8, 8, backButton.frame.size.width, backButton.frame.size.height);
	settingsButton.frame = CGRectMake(size.width - backButton.frame.size.width - 8, 8, backButton.frame.size.width, backButton.frame.size.height);
	tabsButton.frame = CGRectMake(settingsButton.frame.origin.x - backButton.frame.size.width - 8, 8, backButton.frame.size.width, backButton.frame.size.height);
	
	tabCount.frame = CGRectMake(tabsButton.frame.origin.x + 6, tabsButton.frame.origin.y + 12, 14, 10);

	urlField.frame = [self frameForUrlField];
	
	tabScroller.frame = CGRectMake(0, 0, size.width, size.height);
	progressBar.frame = CGRectMake(0, toolbar.frame.size.height - 2, toolbar.frame.size.width, 2);
	tabToolbar.frame = toolbar.frame;
	
	for (int i = 0; i < webViewTabs.count; i++) {
		WebViewTab *wvt = webViewTabs[i];
		[wvt updateFrame:[self frameForTabIndex:i withSize:size]];
	}
	
	tabScroller.contentSize = CGSizeMake(size.width * tabChooser.numberOfPages, size.height);
	
	tabChooser.frame = CGRectMake(0, size.height - 24, size.width, 24);
	
	[self.view setNeedsDisplay];
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

- (NSMutableArray *)webViewTabs
{
	return webViewTabs;
}

- (__strong WebViewTab *)curWebViewTab
{
	if (webViewTabs.count > 0)
		return webViewTabs[tabChooser.currentPage];
	else
		return nil;
}

- (WebViewTab *)addNewTabForURL:(NSURL *)url
{
	WebViewTab *wvt = [[WebViewTab alloc] initWithFrame:[self frameForTabIndex:webViewTabs.count] controller:self];
	
	[wvt.webView.scrollView setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
	[wvt.webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
	[wvt.webView.scrollView setDelegate:self];
	
	[webViewTabs addObject:wvt];
	[tabChooser setNumberOfPages:webViewTabs.count];
	[wvt setTabNumber:[NSNumber numberWithLong:(webViewTabs.count - 1)]];
	
	[tabCount setText:[NSString stringWithFormat:@"%lu", tabChooser.numberOfPages]];

	[tabScroller setContentSize:CGSizeMake(wvt.viewHolder.frame.size.width * tabChooser.numberOfPages, wvt.viewHolder.frame.size.height)];
	[tabScroller addSubview:wvt.viewHolder];
	
	[tabScroller bringSubviewToFront:toolbar];

	if (showingTabs)
		[wvt zoomOut];

	void (^swapToTab)(BOOL) = ^(BOOL finished) {
		tabChooser.currentPage = webViewTabs.count - 1;
		
		[self slideToCurrentTabWithCompletionBlock:^(BOOL finished) {
			if (url != nil)
				[wvt loadURL:url];

			[self showTabsWithCompletionBlock:^(BOOL finished) {
				if (url == nil)
					[urlField becomeFirstResponder];
			}];
		}];
	};
	
	/* animate zooming out (if not already), switching to the new tab, then zoom back in */
	if (showingTabs)
		swapToTab(YES);
	else if (webViewTabs.count > 1)
		[self showTabsWithCompletionBlock:swapToTab];
	else {
		if (url == nil)
			[urlField becomeFirstResponder];
		else
			[wvt loadURL:url];
	}
		
	return wvt;
}

- (void)addNewTabFromToolbar:(id)_id
{
	[self addNewTabForURL:nil];
}

- (CGRect)frameForTabIndex:(NSUInteger)number
{
	return [self frameForTabIndex:number withSize:CGSizeMake(0, 0)];
}

- (CGRect)frameForTabIndex:(NSUInteger)number withSize:(CGSize)size
{
	float screenWidth, screenHeight;
 
	if (size.width == 0) {
		screenWidth = [UIScreen mainScreen].applicationFrame.size.width;
		screenHeight = [UIScreen mainScreen].applicationFrame.size.height;
	
		UIInterfaceOrientation ori = [UIApplication sharedApplication].statusBarOrientation;
		if (ori == UIInterfaceOrientationLandscapeRight || ori == UIInterfaceOrientationLandscapeLeft) {
			float t = screenWidth;
			screenWidth = screenHeight;
			screenHeight = t;
		}
	}
	
	return CGRectMake((screenWidth * number), 32, screenWidth, screenHeight - TOOLBAR_HEIGHT);
}

- (CGRect)frameForUrlField
{
	float x = forwardButton.frame.origin.x + forwardButton.frame.size.width + 8;
	float y = tabsButton.frame.origin.y;
	float w = tabsButton.frame.origin.x - 8 - forwardButton.frame.origin.x - forwardButton.frame.size.width - 8;
	float h = tabsButton.frame.size.height;
	
	if (forwardButton.hidden) {
		x -= forwardButton.frame.size.width + 8;
		w += forwardButton.frame.size.width + 8;
	}
	
	return CGRectMake(x, y, w, h);
}

- (void)removeTab:(NSUInteger)tabNumber
{
#ifdef TRACE
	NSLog(@"removing tab %lu (%@)", tabNumber, ((WebViewTab *)webViewTabs[tabNumber]).title.text);
#endif
	[[webViewTabs[tabNumber] viewHolder] removeFromSuperview];
	[webViewTabs removeObjectAtIndex:tabNumber];

	[tabChooser setNumberOfPages:webViewTabs.count];
	[tabCount setText:[NSString stringWithFormat:@"%lu", tabChooser.numberOfPages]];

	if (tabChooser.currentPage == tabNumber) {
		if (webViewTabs.count > tabNumber && webViewTabs[tabNumber]) {
			/* keep currentPage pointing at the page that shifted down to here */
		}
		else if (tabNumber > 0 && webViewTabs[tabNumber - 1]) {
			/* removed last tab, keep the previous one */
			tabChooser.currentPage = tabNumber - 1;
		}
		else {
			/* no tabs left, add one and zoom out */
			[self addNewTabForURL:nil];
			return;
		}
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
		[self slideToCurrentTab:nil];
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
				if ([progressBar progress] == 0) {
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
			[urlField setLeftView:blankIcon];
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
			
			if ([urlField.text isEqualToString:@""])
				[urlField setTextAlignment:NSTextAlignmentLeft];
		}
	}
	
	backButton.enabled = (self.curWebViewTab && self.curWebViewTab.canGoBack);
	forwardButton.hidden = !(self.curWebViewTab && self.curWebViewTab.canGoForward);
	[urlField setFrame:[self frameForUrlField]];
}

- (void)setWebViewProgress:(float)progress
{
	BOOL animated = YES;
	float fadeAnimationDuration = 0.15;
	float fadeOutDelay = 0.3;
	
#ifdef TRACE
	NSLog(@"loading progress of %@ at %f", [self.curWebViewTab.url absoluteString], progress);
#endif

	[self updateSearchBarDetails];
	
	if (progress >= 1.0) {
		[progressBar setProgress:progress animated:NO];

		[UIView animateWithDuration:fadeAnimationDuration delay:fadeOutDelay options:UIViewAnimationOptionCurveLinear animations:^{
			progressBar.alpha = 0.0;
		} completion:^(BOOL finished) {
			progressBar.progress = 0.0;
			[self updateSearchBarDetails];
		}];
	}
	else {
		[progressBar setProgress:progress animated:animated];
		
		[UIView animateWithDuration:(animated ? fadeAnimationDuration : 0.0) delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
			if (showingTabs)
				progressBar.alpha = 0.0;
			else
				progressBar.alpha = 1.0;
		} completion:nil];
	}
}

- (void)updateProgress
{
	[self setWebViewProgress:[[self curWebViewTab] progress]];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	if (textField != urlField)
		return;

#ifdef TRACE
	NSLog(@"started editing");
#endif
	[urlField setTextAlignment:NSTextAlignmentNatural];
	
	[urlField setText:[self.curWebViewTab.url absoluteString]];
	[self updateSearchBarDetails];
	
	[urlField performSelector:@selector(selectAll:) withObject:nil afterDelay:0.0];
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
	if (textField != urlField)
		return;

#ifdef TRACE
	NSLog(@"ended editing with: %@", [textField text]);
#endif
	[urlField setTextAlignment:NSTextAlignmentCenter];
	
	[self updateSearchBarDetails];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if (textField == urlField) {
		NSURL *enteredURL = [NSURL URLWithString:urlField.text];
		
		if (![enteredURL scheme] || [[enteredURL scheme] isEqualToString:@""]) {
			/* no scheme so if it has a space or no dots, assume it's a search query */
			if ([urlField.text containsString:@" "] || ![urlField.text containsString:@"."]) {
				NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
				NSDictionary *se = [[appDelegate searchEngines] objectForKey:[userDefaults stringForKey:@"search_engine"]];
				
				enteredURL = [NSURL URLWithString:[[NSString stringWithFormat:[se objectForKey:@"search_url"], urlField.text] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
			}
			else
				enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", urlField.text]];
			
#ifdef TRACE
			NSLog(@"typed URL transformed to %@", enteredURL);
#endif
		}
		
		[urlField resignFirstResponder]; /* will unfocus and call textFieldDidEndEditing */

		[[self curWebViewTab] loadURL:enteredURL];
		
		return NO;
	}
	return YES;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	if (scrollView == tabScroller) {
		int page = round(scrollView.contentOffset.x / scrollView.frame.size.width);
		if (page < 0)
			page = 0;
		else if (page > tabChooser.numberOfPages)
			page = (int)tabChooser.numberOfPages;

		tabChooser.currentPage = page;
	}
}

- (void)goBack:(id)_id
{
	[self.curWebViewTab goBack];
}

- (void)goForward:(id)_id
{
	[self.curWebViewTab goForward];
}

- (void)showSettings:(id)_id
{
	if (!appSettingsViewController) {
		appSettingsViewController = [[IASKAppSettingsViewController alloc] init];
		appSettingsViewController.delegate = self;
		appSettingsViewController.showDoneButton = YES;
		appSettingsViewController.showCreditsFooter = NO;
	}
	
	UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:appSettingsViewController];
	[self presentViewController:aNavController animated:YES completion:nil];
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[URLInterceptor setSendDNT:[userDefaults boolForKey:@"send_dnt"]];
}

- (void)showTabs:(id)_id
{
	return [self showTabsWithCompletionBlock:nil];
}

- (void)showTabsWithCompletionBlock:(void(^)(BOOL))block
{
	if (showingTabs) {
		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < webViewTabs.count; i++)
				[(WebViewTab *)webViewTabs[i] zoomNormal];
			
			tabChooser.hidden = true;
			toolbar.hidden = false;
			tabToolbar.hidden = true;
			progressBar.alpha = 1.0;
			
			tabScroller.frame = origTabScrollerFrame;
		} completion:block];

		tabScroller.scrollEnabled = NO;
		tabScroller.pagingEnabled = NO;
		
		[self updateSearchBarDetails];
	}
	else {
		/* make sure no text is selected */
		[urlField resignFirstResponder];
		
		origTabScrollerFrame = tabScroller.frame;
		
		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < webViewTabs.count; i++)
				[(WebViewTab *)webViewTabs[i] zoomOut];
			
			tabChooser.hidden = false;
			toolbar.hidden = true;
			tabToolbar.hidden = false;
			progressBar.alpha = 0.0;
			
			tabScroller.frame = CGRectMake(tabScroller.frame.origin.x, 0, tabScroller.frame.size.width, tabScroller.frame.size.height);
		} completion:block];
		
		tabScroller.contentOffset = CGPointMake([self frameForTabIndex:tabChooser.currentPage].origin.x, 0);
		tabScroller.scrollEnabled = YES;
		tabScroller.pagingEnabled = YES;
		
		UITapGestureRecognizer *singleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedOnWebViewTab:)];
		singleTapGestureRecognizer.numberOfTapsRequired = 1;
		singleTapGestureRecognizer.enabled = YES;
		singleTapGestureRecognizer.cancelsTouchesInView = NO;
		[tabScroller addGestureRecognizer:singleTapGestureRecognizer];
	}
	
	showingTabs = !showingTabs;
}

- (void)doneWithTabsButton:(id)_id
{
	[self showTabs:nil];
}

- (void)tappedOnWebViewTab:(UITapGestureRecognizer *)gesture
{
	if (!showingTabs)
		return;
	
	CGPoint point = [gesture locationInView:self.curWebViewTab.viewHolder];
	
	/* fuzz a bit to make it easier to tap */
	int fuzz = 8;
	CGRect closerFrame = CGRectMake(self.curWebViewTab.closer.frame.origin.x - fuzz, self.curWebViewTab.closer.frame.origin.y - fuzz, self.curWebViewTab.closer.frame.size.width + (fuzz * 2), self.curWebViewTab.closer.frame.size.width + (fuzz * 2));
	if (CGRectContainsPoint(closerFrame, point))
		[self removeTab:tabChooser.currentPage];
	else
		[self showTabs:nil];
}

- (void)slideToCurrentTabWithCompletionBlock:(void(^)(BOOL))block
{
	[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		[tabScroller setContentOffset:CGPointMake([self frameForTabIndex:tabChooser.currentPage].origin.x, 0) animated:NO];
	} completion:block];
}

- (IBAction)slideToCurrentTab:(id)_id
{
	[self slideToCurrentTabWithCompletionBlock:nil];
}

@end
