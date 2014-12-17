#import "AppDelegate.h"
#import "WebViewController.h"
#import "IASKAppSettingsViewController.h"
#import "URLInterceptor.h"
#import "WebViewTab.h"

#define STATUSBAR_HEIGHT 16
#define SEARCHBAR_HEIGHT 48
#define TOOLBAR_HEIGHT 44

@interface WebViewController ()

@end

@implementation WebViewController {
	IBOutlet UIScrollView *tabScroller;
	UIPageControl *tabChooser;
	NSMutableArray *webViewTabs;

	IBOutlet UISearchBar *searchBar;
	IBOutlet UIProgressView *progressBar;
	IBOutlet UIToolbar *toolbar;
	IBOutlet UIToolbar *tabToolbar;
	
	IBOutlet UIBarButtonItem *backButton;
	IBOutlet UIBarButtonItem *forwardButton;
	IBOutlet UIBarButtonItem *shareButton;
	IBOutlet UIBarButtonItem *bookmarksButton;
	IBOutlet UIBarButtonItem *tabsButton;
	IBOutlet UIBarButtonItem *settingsButton;
	
	IBOutlet UIBarButtonItem *tabAddButton;
	IBOutlet UIBarButtonItem *tabDoneButton;

	AppDelegate *appDelegate;
	
	IASKAppSettingsViewController *appSettingsViewController;
	
	float lastWebViewScrollOffset;
	CGRect origTabScrollerFrame;
	BOOL showingTabs;
	BOOL webViewScrollIsDecelerating;
	BOOL webViewScrollIsDragging;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate setWebViewController:self];
	
	webViewTabs = [[NSMutableArray alloc] initWithCapacity:10];
	
	[self adjustLayoutToSize:CGSizeMake(self.view.bounds.size.width, self.view.bounds.size.height)];
	
	[progressBar setTrackTintColor:[searchBar barTintColor]];
	[progressBar setProgress:0.0];
	
	[tabScroller setAutoresizingMask:(UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight)];
	[tabScroller setAutoresizesSubviews:NO];
	[tabScroller setShowsHorizontalScrollIndicator:NO];
	[tabScroller setShowsVerticalScrollIndicator:NO];
	[tabScroller setScrollsToTop:NO];
	[tabScroller setDelaysContentTouches:NO];
	[tabScroller setDelegate:self];
	
	tabChooser = [[UIPageControl alloc] initWithFrame:CGRectMake(0, toolbar.frame.origin.y - 35, self.view.frame.size.width, 35)];
	[tabChooser setAutoresizingMask:(UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin)];
	[tabChooser addTarget:self action:@selector(slideToCurrentTab:) forControlEvents:UIControlEventValueChanged];
	[tabChooser setPageIndicatorTintColor:[UIColor colorWithRed:0.8 green:0.8 blue:0.8 alpha:1.0]];
	[tabChooser setCurrentPageIndicatorTintColor:[UIColor grayColor]];
	[tabChooser setNumberOfPages:0];
	[self.view insertSubview:tabChooser aboveSubview:toolbar];
	[tabChooser setHidden:true];
	
	/* hook up toolbar buttons */
	backButton.target = self;
	backButton.action = @selector(goBack:);
	forwardButton.target = self;
	forwardButton.action = @selector(goForward:);
	settingsButton.target = self;
	settingsButton.action = @selector(showSettings:);
	tabsButton.target = self;
	tabsButton.action = @selector(showTabs:);
	shareButton.target = self;
	shareButton.action = @selector(showShareMenu:);
	
	tabAddButton.target = self;
	tabAddButton.action = @selector(addNewTabFromToolbar:);
	tabDoneButton.target = self;
	tabDoneButton.action = @selector(doneWithTabsButton:);
	[tabToolbar setHidden:true];
	
	[[self searchBarTextField] setClearButtonMode:UITextFieldViewModeWhileEditing];
	[self updateSearchBarDetails];
	
	[self.view.window makeKeyAndVisible];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *se = [[appDelegate searchEngines] objectForKey:[userDefaults stringForKey:@"search_engine"]];
	
	WebViewTab *wvt = [self addNewTabAndFocus:YES];
	[wvt loadURL:[NSURL URLWithString:[se objectForKey:@"homepage_url"]]];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
	[self adjustLayoutToSize:size];
}

- (void)adjustLayoutToSize:(CGSize)size
{
	self.view.frame = CGRectMake(0, 0, size.width, size.height);
	
	searchBar.frame = CGRectMake(0, STATUSBAR_HEIGHT, size.width, SEARCHBAR_HEIGHT);
	tabScroller.frame = CGRectMake(0, 0, size.width, size.height);
	progressBar.frame = CGRectMake(0, searchBar.frame.origin.y + searchBar.frame.size.height, searchBar.frame.size.width, 2);
	
	toolbar.frame = tabToolbar.frame = CGRectMake(0, size.height - TOOLBAR_HEIGHT, size.width, TOOLBAR_HEIGHT);
	
	for (int i = 0; i < webViewTabs.count; i++) {
		WebViewTab *wvt = webViewTabs[i];
		[wvt updateFrame:[self frameForTabIndex:i withSize:size]];
	}
	
	tabScroller.contentSize = CGSizeMake(size.width * tabChooser.numberOfPages, size.height);
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

- (WebViewTab *)addNewTabAndFocus:(BOOL)focus
{
	WebViewTab *wvt = [[WebViewTab alloc] initWithFrame:[self frameForTabIndex:webViewTabs.count] controller:self];
	
	[wvt.webView.scrollView setContentInset:UIEdgeInsetsMake(0, 0, TOOLBAR_HEIGHT, 0)];
	[wvt.webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, TOOLBAR_HEIGHT, 0)];
	[wvt.webView.scrollView setDelegate:self];
	
	[webViewTabs addObject:wvt];
	[tabScroller addSubview:wvt.viewHolder];

	if (showingTabs)
		[wvt zoomOut];
	
	[tabChooser setNumberOfPages:webViewTabs.count];
	
	[wvt setTabNumber:[NSNumber numberWithLong:(webViewTabs.count - 1)]];

	if (focus) {
		void (^swapToTab)(BOOL) = ^(BOOL finished) {
			tabChooser.currentPage = webViewTabs.count - 1;
			
			[self slideToCurrentTab:nil withCompletionBlock:^(BOOL finished) {
				//[self showTabs:nil];
			}];
		};
		
		/* animate zooming out (if not already), switching to the new tab, then zoom back in */
		if (!showingTabs && webViewTabs.count > 1) {
			[self showTabs:nil withCompletionBlock:swapToTab];
		}
		else if (showingTabs) {
			swapToTab(YES);
		}
	}
	
	return wvt;
}

- (void)addNewTabFromToolbar:(id)_id
{
	[self addNewTabAndFocus:YES];
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
	
	return CGRectMake(screenWidth * number, SEARCHBAR_HEIGHT - STATUSBAR_HEIGHT, screenWidth, screenHeight - TOOLBAR_HEIGHT);
}

- (void)removeTab:(NSUInteger)tabNumber
{
#ifdef TRACE
	NSLog(@"removing tab %lu (%@)", tabNumber, ((WebViewTab *)webViewTabs[tabNumber]).title.text);
#endif
	[[webViewTabs[tabNumber] viewHolder] removeFromSuperview];
	[webViewTabs removeObjectAtIndex:tabNumber];

	tabChooser.numberOfPages = webViewTabs.count;

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
			[self addNewTabAndFocus:true];
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
	NSString *evOrg;
	
	/* TODO: cache curURL and only do anything here if it changed, these changes might be expensive */

	if (searchBar.isFirstResponder) {
		/* focused, don't muck with the URL while it's being edited */
		
		[[self searchBarTextField] setTextAlignment:NSTextAlignmentNatural];
		[[self searchBarTextField] setTextColor:[UIColor darkTextColor]];
		[searchBar setShowsCancelButton:YES animated:YES];
		[searchBar setImage:UISearchBarIconSearch forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
	}
	else {
		[self.searchBarTextField setTextAlignment:NSTextAlignmentCenter];
		[searchBar setShowsCancelButton:NO animated:YES];

		if (self.curWebViewTab && self.curWebViewTab.url != nil && [[self.curWebViewTab.url scheme] isEqualToString:@"https"]) {
			evOrg = [[appDelegate evHosts] objectForKey:[self.curWebViewTab.url host]];

			[searchBar setImage:[UIImage imageNamed:@"lock"] forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
		}
		else {
			/* XXX: is this legal? */
			[searchBar setImage:[UIImage new] forSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
		}
		
		if (evOrg != nil && ![evOrg isEqualToString:@""] && [progressBar progress] == 0) {
			[[self searchBarTextField] setTextColor:[UIColor colorWithRed:0 green:(183.0/255.0) blue:(82.0/255.0) alpha:1.0]];
			
			[searchBar setText:evOrg];
		}
		else {
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
			
			[[self searchBarTextField] setTextColor:[UIColor darkTextColor]];
			[searchBar setText:hostNoWWW];
		}
		
		if ([searchBar.text isEqualToString:@""])
			[self.searchBarTextField setTextAlignment:NSTextAlignmentLeft];
	}
	
	backButton.enabled = (self.curWebViewTab && self.curWebViewTab.canGoBack);
	forwardButton.enabled = (self.curWebViewTab && self.curWebViewTab.canGoForward);
}

- (__strong UITextField *)searchBarTextField
{
	for (UIView *subView in searchBar.subviews) {
		for (id field in subView.subviews) {
			if ([field isKindOfClass:[UITextField class]]) {
				UITextField *textField = (UITextField *)field;
				return textField;
			}
		}
	}
	return nil;
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

- (void)searchBarTextDidBeginEditing:(UISearchBar *)_searchBar
{
#ifdef TRACE
	NSLog(@"started editing");
#endif
	UITextField *sbtf = [self searchBarTextField];
	[sbtf setTextAlignment:NSTextAlignmentNatural];
	
	[searchBar setText:[self.curWebViewTab.url absoluteString]];
	[self updateSearchBarDetails];
	
	[sbtf performSelector:@selector(selectAll:) withObject:nil afterDelay:0.0];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)_searchBar
{
#ifdef TRACE
	NSLog(@"ended editing with: %@", [_searchBar text]);
#endif
	UITextField *sbtf = [self searchBarTextField];
	[sbtf setTextAlignment:NSTextAlignmentCenter];
	
	[self updateSearchBarDetails];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)_searchBar
{
#ifdef TRACE
	NSLog(@"cancel button clicked");
#endif
	[searchBar resignFirstResponder];
}

- (void)searchBarResultsListButtonClicked:(UISearchBar *)searchBar
{
	NSLog(@"results list button clicked");
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)_searchBar
{
	NSURL *enteredURL = [NSURL URLWithString:searchBar.text];
	
	if (![enteredURL scheme] || [[enteredURL scheme] isEqualToString:@""]) {
		/* no scheme so if it has a space or no dots, assume it's a search query */
		if ([searchBar.text containsString:@" "] || ![searchBar.text containsString:@"."]) {
			NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
			NSDictionary *se = [[appDelegate searchEngines] objectForKey:[userDefaults stringForKey:@"search_engine"]];
			
			enteredURL = [NSURL URLWithString:[[NSString stringWithFormat:[se objectForKey:@"search_url"], searchBar.text] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
		}
		else
			enteredURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://%@", searchBar.text]];
		
#ifdef TRACE
		NSLog(@"typed URL transformed to %@", enteredURL);
#endif
	}
	
	[searchBar resignFirstResponder]; /* will unfocus and call searchBarTextDidEndEditing */

	[[self curWebViewTab] loadURL:enteredURL];
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
	else if (scrollView == self.curWebViewTab.webView.scrollView && !showingTabs) {
		if (scrollView.contentOffset.y < 0)
			lastWebViewScrollOffset = 0;
		
		if (!webViewScrollIsDragging) {
			lastWebViewScrollOffset = scrollView.contentOffset.y;
			return;
		}

		float y = toolbar.frame.origin.y;
		
		if (lastWebViewScrollOffset < scrollView.contentOffset.y) {
			/* scrolling down the page, content moving up, always start hiding bar */
			y += (scrollView.contentOffset.y - lastWebViewScrollOffset) * 0.75;
		}
		/* scrolling up, require a big jump to initiate, then fully show the bar */
		else if ((lastWebViewScrollOffset - scrollView.contentOffset.y) >= 3) {
			[UIView animateWithDuration:0.5 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
				 CGRect toolbarFrame = CGRectMake(0, self.view.frame.size.height - TOOLBAR_HEIGHT, self.view.frame.size.width, TOOLBAR_HEIGHT);
				 toolbar.frame = toolbarFrame;
			 }
			 completion:^(BOOL finished) {
				 CGRect toolbarFrame = CGRectMake(0, self.view.frame.size.height - TOOLBAR_HEIGHT, self.view.frame.size.width, TOOLBAR_HEIGHT);
				 toolbar.frame = toolbarFrame;
				 lastWebViewScrollOffset = scrollView.contentOffset.y;
			 }];
		}
		
		y = MAX(self.view.frame.size.height - TOOLBAR_HEIGHT, y);
		y = MIN(self.view.frame.size.height, y);

		CGRect toolbarFrame = CGRectMake(0, y, self.view.frame.size.width, TOOLBAR_HEIGHT);
		toolbar.frame = toolbarFrame;
		
		if (y >= self.view.frame.size.height - TOOLBAR_HEIGHT) {
			[self.curWebViewTab.webView.scrollView setContentInset:UIEdgeInsetsMake(0, 0, 0, 0)];
			[self.curWebViewTab.webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, 0, 0)];
		} else {
			[self.curWebViewTab.webView.scrollView setContentInset:UIEdgeInsetsMake(0, 0, TOOLBAR_HEIGHT, 0)];
			[self.curWebViewTab.webView.scrollView setScrollIndicatorInsets:UIEdgeInsetsMake(0, 0, TOOLBAR_HEIGHT, 0)];
		}
		
		lastWebViewScrollOffset = scrollView.contentOffset.y;
	}
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
	if (scrollView == self.curWebViewTab.webView.scrollView)
		webViewScrollIsDragging = YES;
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (scrollView == self.curWebViewTab.webView.scrollView)
		webViewScrollIsDragging = NO;
}

- (void)scrollViewWillBeginDecelerating:(UIScrollView *)scrollView
{
	if (scrollView == self.curWebViewTab.webView.scrollView)
		webViewScrollIsDecelerating = YES;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
	if (scrollView == self.curWebViewTab.webView.scrollView)
		webViewScrollIsDecelerating = NO;
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

- (void)showShareMenu:(id)_id
{
	/* TODO */
}

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController *)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	[URLInterceptor setSendDNT:[userDefaults boolForKey:@"send_dnt"]];
}

- (void)showTabs:(id)_id
{
	return [self showTabs:_id withCompletionBlock:nil];
}

- (void)showTabs:(id)_id withCompletionBlock:(void(^)(BOOL))block
{
	if (showingTabs) {
		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < webViewTabs.count; i++)
				[(WebViewTab *)webViewTabs[i] zoomNormal];
			
			tabChooser.hidden = true;
			toolbar.hidden = false;
			tabToolbar.hidden = true;
			searchBar.alpha = 1.0;
			progressBar.alpha = 1.0;
			
			tabScroller.frame = origTabScrollerFrame;
		} completion:block];

		tabScroller.scrollEnabled = NO;
		tabScroller.pagingEnabled = NO;
		
		[self updateSearchBarDetails];
	}
	else {
		/* make sure no text is selected */
		[searchBar resignFirstResponder];
		
		origTabScrollerFrame = tabScroller.frame;

		[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^(void) {
			for (int i = 0; i < webViewTabs.count; i++)
				[(WebViewTab *)webViewTabs[i] zoomOut];
			
			tabChooser.hidden = false;
			toolbar.hidden = true;
			tabToolbar.hidden = false;
			searchBar.alpha = 0.0;
			progressBar.alpha = 0.0;
			
			tabScroller.frame = CGRectMake(tabScroller.frame.origin.x, -(tabChooser.frame.size.height), tabScroller.frame.size.width, tabScroller.frame.size.height);
		} completion:block];
		
		tabScroller.contentSize = CGSizeMake(self.view.frame.size.width * tabChooser.numberOfPages, self.view.frame.size.height);
		tabScroller.contentOffset = CGPointMake(tabScroller.frame.size.width * tabChooser.currentPage, 0);
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

- (void)slideToCurrentTab:(id)_id withCompletionBlock:(void(^)(BOOL))block
{
	[UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
		CGRect destFrame = [self frameForTabIndex:tabChooser.currentPage];
		[tabScroller setContentOffset:CGPointMake(destFrame.origin.x, 0) animated:NO];
	} completion:block];
}

- (IBAction)slideToCurrentTab:(id)_id
{
	[self slideToCurrentTab:_id withCompletionBlock:nil];
}

@end
