/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "AppDelegate.h"
#import "HostSettings.h"
#import "HostSettingsController.h"

#import "QuickDialog.h"

@implementation HostSettingsController

AppDelegate *appDelegate;
NSMutableArray *_sortedHosts;
NSString *firstMatch;

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	
	self.title = @"Host Settings";
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addHost:)];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];
	
	/* most likely the user is wanting to define the site they are currently on, so feed that as a reasonable default the first time around */
	if ([[appDelegate webViewController] curWebViewTab] != nil) {
		NSURL *t = [[[appDelegate webViewController] curWebViewTab] url];
		if (t != nil && [t host] != nil) {
			NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"^www\\." options:NSRegularExpressionCaseInsensitive error:nil];
			
			firstMatch = [r stringByReplacingMatchesInString:[t host] options:0 range:NSMakeRange(0, [[t host] length]) withTemplate:@""];
		}
	}
}

- (void)viewWillDisappear:(BOOL)animated
{
	[HostSettings persist];
}

- (void)didReceiveMemoryWarning
{
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [[self sortedHosts] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"host"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"host"];
	
	cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	
	HostSettings *hs = [HostSettings settingsForHost:[[self sortedHosts] objectAtIndex:indexPath.row]];
	cell.textLabel.text = [hs hostname];

	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return (indexPath.row != 0);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	
	HostSettings *host = [HostSettings settingsForHost:[[self sortedHosts] objectAtIndex:indexPath.row]];
	
	QRootElement *root = [[QRootElement alloc] init];
	root.grouped = YES;
	root.appearance = [root.appearance copy];
	
	root.appearance.labelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
	root.appearance.valueColorEnabled = [UIColor darkTextColor];

	root.title = [host hostname];
	
	QSection *section = [[QSection alloc] init];
	
	QEntryElement *hostname;
	if (indexPath.row == 0) {
		QLabelElement *label = [[QLabelElement alloc] initWithTitle:@"Host/domain" Value:[host hostname]];
		[section addElement:label];
		[section setFooter:@"These settings will be used as defaults for all hosts without host definitions"];
	}
	else {
		hostname = [[QEntryElement alloc] initWithTitle:@"Host/domain" Value:[host hostname] Placeholder:@"example.com"];
		[section addElement:hostname];
		[section setFooter:@"These settings will apply to all hosts under this domain/host"];
	}

	[root addSection:section];
	
	section = [[QSection alloc] init];
	[section setTitle:@"Security"];
	
	QRadioElement *tls = [[QRadioElement alloc] initWithDict:@{
								   @"TLS 1.2 only (no SSL)" : HOST_SETTINGS_MIN_TLS_12,
								   @"TLS 1.1 or 1.2 (no SSL)" : HOST_SETTINGS_MIN_TLS_11,
								   @"TLS 1.0, 1.1, or 1.2 (no SSL)" : HOST_SETTINGS_MIN_TLS_10,
								   @"Auto-negotiate (SSL v2/v3, TLS 1.0/1.1/1.2)" : HOST_SETTINGS_MIN_TLS_AUTO,
								   } selected:0 title:@"Minimum SSL/TLS version"];
	[tls setShortItems:@[ @"TLS 1.2", @"TLS 1.1", @"TLS 1.0", @"Auto" ]];
	[tls setKey:HOST_SETTINGS_KEY_MIN_TLS];
	[tls setSelectedValue:[host minTLSVersion]];
	[section setFooter:@"Minimum version of SSL/TLS required by this host to negotiate HTTPS connections"];
	[section addElement:tls];
	[root addSection:section];
	
	section = [[QSection alloc] init];
	QBooleanElement *exlan = [[QBooleanElement alloc] initWithKey:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS];
	[exlan setTitle:@"Block external LAN requests"];
	[exlan setBoolValue:[host blockIntoLocalNets]];
	[section addElement:exlan];
	[section setFooter:@"Resources loaded from this host will be blocked from loading page elements or making requests to LAN hosts (192.168.0.0/16, 172.16.0.0/12, etc.)"];
	[root addSection:section];
	
	section = [[QSection alloc] init];
	[section setTitle:@"Privacy"];
	
	QBooleanElement *whitelistCookies = [[QBooleanElement alloc] initWithKey:HOST_SETTINGS_KEY_WHITELIST_COOKIES];
	[whitelistCookies setTitle:@"Allow persistent cookies"];
	[whitelistCookies setBoolValue:[host whitelistCookies]];
	[section addElement:whitelistCookies];
	
	[root addSection:section];

	QuickDialogController *qdc = [QuickDialogController controllerForRoot:root];

	[qdc setWillDisappearCallback:^{
		if (![host isDefault])
			[host setHostname:[hostname textValue]];
		
		[host setMinTLSVersion:(NSString *)[tls selectedValue]];
		[host setBlockIntoLocalNets:[exlan boolValue]];
		[host setWhitelistCookies:[whitelistCookies boolValue]];

		[host save];
	}];
	
	[[self navigationController] pushViewController:qdc animated:YES];
	self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Hosts" style:UIBarButtonItemStylePlain target:nil action:nil];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		if ([HostSettings removeSettingsForHost:[[self sortedHosts] objectAtIndex:indexPath.row]]) {
			[tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationFade];
			_sortedHosts = nil;
			[[self tableView] reloadData];
		}
	}
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (void)addHost:sender
{
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Host settings" message:@"Enter the host/domain to define settings for" preferredStyle:UIAlertControllerStyleAlert];
	[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = @"example.com";
		
		if (firstMatch != nil)
			textField.text = firstMatch;
	}];
	
	UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		UITextField *host = alertController.textFields.firstObject;
		if (host && ![[host text] isEqualToString:@""]) {
			HostSettings *hs = [[HostSettings alloc] initForHost:[host text] withDict:nil];
			[hs save];
			_sortedHosts = nil;
			
			[self.tableView reloadData];
			/* TODO: go to edit view */
		}
	}];
	
	UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Cancel action") style:UIAlertActionStyleCancel handler:nil];
	[alertController addAction:cancelAction];
	[alertController addAction:okAction];
	
	[self presentViewController:alertController animated:YES completion:nil];
	
	firstMatch = nil;
}

- (NSMutableArray *)sortedHosts
{
	if (_sortedHosts == nil)
		_sortedHosts = [[NSMutableArray alloc] initWithArray:[HostSettings sortedHosts]];
	
	return _sortedHosts;
}

@end
