/*
 * Endless
 * Copyright (c) 2015-2018 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "SearchResultsController.h"
#import "URLInterceptor.h"

#import "NSString+DTURLEncoding.h"

@implementation SearchResultsController {
	AppDelegate *appDelegate;
	NSString *lastQuery;
	NSArray *lastResults;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	self.title = NSLocalizedString(@"Search Results", nil);
	
	if ([[appDelegate webViewController] darkInterface])
		[[self tableView] setBackgroundColor:[UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0]];
	
	lastResults = @[];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[[appDelegate webViewController] hideSearchResults];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [lastResults count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return NSLocalizedString(@"Search Results", nil);
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
	if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
		UITableViewHeaderFooterView *tableViewHeaderFooterView = (UITableViewHeaderFooterView *) view;
		int buttonSize = tableViewHeaderFooterView.frame.size.height - 8;
		
		UIButton *b = [[UIButton alloc] init];
		[b setFrame:CGRectMake(tableViewHeaderFooterView.frame.size.width - buttonSize - 6, 3, buttonSize, buttonSize)];
		[b setBackgroundColor:[UIColor lightGrayColor]];
		[b setTitle:@"X" forState:UIControlStateNormal];
		[[b titleLabel] setFont:[UIFont boldSystemFontOfSize:12]];
		[[b layer] setCornerRadius:buttonSize / 2];
		[b setClipsToBounds:YES];
		
		[b addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];
		
		[tableViewHeaderFooterView addSubview:b];
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"result"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"result"];
	
	cell.textLabel.text = [lastResults objectAtIndex:indexPath.row];
	
	[cell setShowsReorderControl:NO];
	
	if ([[appDelegate webViewController] darkInterface]) {
		[cell setBackgroundColor:[UIColor clearColor]];
		[[cell textLabel] setTextColor:[UIColor whiteColor]];
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSString *q = [lastResults objectAtIndex:indexPath.row];
	
	if (q)
		[[[appDelegate webViewController] curWebViewTab] searchFor:q];
	
	[[appDelegate webViewController] unfocusUrlField];

	[self close];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return YES;
}

- (void)close
{
	[self removeFromParentViewController];
	[[self view] removeFromSuperview];
}

- (void)updateSearchResultsForQuery:(NSString *)query
{
	if (query == nil || [query isEqualToString:@""] || (lastQuery != nil && [lastQuery isEqualToString:query]))
		return;
	
#ifdef TRACE
	NSLog(@"[SearchResultsController] need to autocomplete search for \"%@\"", query);
#endif
	
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *se = [[appDelegate searchEngines] objectForKey:[userDefaults stringForKey:@"search_engine"]];
	
	if (se == nil)
		/* just pick the first search engine */
		se = [[appDelegate searchEngines] objectForKey:[[[appDelegate searchEngines] allKeys] firstObject]];
	
	NSDictionary *pp = [se objectForKey:@"post_params"];
	NSString *urls;
	if (pp == nil)
		urls = [NSString stringWithFormat:[se objectForKey:@"autocomplete_url"], [query stringByURLEncoding]];
	else
		urls = [se objectForKey:@"autocomplete_url"];
	
	NSURL *url = [NSURL URLWithString:urls];
	NSMutableURLRequest *request;
	if (pp == nil) {
#ifdef TRACE
		NSLog(@"[SearchResultsController] auto-completing %@", url);
#endif
		request = [[NSMutableURLRequest alloc] initWithURL:url];
	}
	else {
		/* need to send this as a POST, so build our key val pairs */
		NSMutableString *params = [NSMutableString stringWithFormat:@""];
		for (NSString *key in [pp allKeys]) {
			if (![params isEqualToString:@""])
				[params appendString:@"&"];
			
			[params appendString:[key stringByURLEncoding]];
			[params appendString:@"="];
			
			NSString *val = [pp objectForKey:key];
			if ([val isEqualToString:@"%@"])
				val = [query stringByURLEncoding];
			[params appendString:val];
		}
		
#ifdef TRACE
		NSLog(@"[SearchResultsController] auto-completing via POST to %@ (with params %@)", url, params);
#endif
		
		request = [[NSMutableURLRequest alloc] initWithURL:url];
		[request setHTTPMethod:@"POST"];
		[request setHTTPBody:[params dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	/* so URLInterceptor leaves us alone */
	[NSURLProtocol setProperty:@YES forKey:REWRITTEN_KEY inRequest:request];
	
	__block NSString *tquery = [query copy];
	NSURLSessionDataTask *t = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
		if (error != nil) {
			NSLog(@"[SearchResultsController] failed auto-completing: %@", error);
			return;
		}
		
		if (![lastQuery isEqualToString:tquery]) {
			NSLog(@"[SearchResultsController] stale query results, ignoring");
			return;
		}
		
		NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
		if ([httpResponse statusCode] != 200) {
			NSLog(@"[SearchResultsController] failed auto-completing, status %ld", [httpResponse statusCode]);
			return;
		}
		
		@try {
			NSString *ct = [[httpResponse allHeaderFields] objectForKey:@"Content-Type"];
			if (ct != nil && ([ct containsString:@"javascript"] || [ct containsString:@"json"])) {
				NSArray *res = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
				lastResults = [res objectAtIndex:1];
			} else {
				lastResults = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"\n"];
			}
#ifdef TRACE
			NSLog(@"[SearchResultsController] auto-complete results: %@", lastResults);
#endif
			dispatch_sync(dispatch_get_main_queue(), ^{
				[[self tableView] reloadData];
			});
		}
		@catch(NSException *e) {
			NSLog(@"[SearchResultsController] failed parsing JSON: %@", e);
		}
	}];
	lastQuery = tquery;
	[t resume];
}

@end
