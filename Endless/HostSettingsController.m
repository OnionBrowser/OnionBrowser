/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "HostSettings.h"
#import "HostSettingsController.h"

#import "QuickDialog.h"

@implementation HostSettingsController {
	AppDelegate *appDelegate;
	NSMutableArray *_sortedHosts;
	NSString *firstMatch;
}

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
	
	HostSettings *hs = [HostSettings forHost:[[self sortedHosts] objectAtIndex:indexPath.row]];
	cell.textLabel.text = [hs hostname];
	if ([hs isDefault])
		cell.textLabel.font = [UIFont boldSystemFontOfSize:cell.textLabel.font.pointSize];
	else
		cell.detailTextLabel.text = nil;

	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return (indexPath.row != 0);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	[self showDetailsForHost:[[self sortedHosts] objectAtIndex:indexPath.row]];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		if ([HostSettings removeSettingsForHost:[[self sortedHosts] objectAtIndex:indexPath.row]]) {
			[HostSettings persist];
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
			[HostSettings persist];
			_sortedHosts = nil;
			
			[self.tableView reloadData];
			[self showDetailsForHost:[host text]];
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

- (void)showDetailsForHost:(NSString *)thost
{
	NSString *val;
	
	HostSettings *host = [HostSettings forHost:thost];
	
	QRootElement *root = [[QRootElement alloc] init];
	root.grouped = YES;
	root.appearance = [root.appearance copy];
	
	root.appearance.labelFont = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
	root.appearance.valueColorEnabled = [UIColor darkTextColor];
	
	root.title = [host hostname];
	
	QSection *section = [[QSection alloc] init];
	
	QEntryElement *hostname;
	if ([host isDefault]) {
		QLabelElement *label = [[QLabelElement alloc] initWithTitle:@"Host/domain" Value:HOST_SETTINGS_HOST_DEFAULT_LABEL];
		[section addElement:label];
		[section setFooter:@"These settings will be used as defaults for all hosts unless overridden"];
	}
	else {
		hostname = [[QEntryElement alloc] initWithTitle:@"Host/domain" Value:[host hostname] Placeholder:@"example.com"];
		[section addElement:hostname];
		[section setFooter:@"These settings will apply to all hosts under this domain"];
	}
	
	[root addSection:section];
	
	/* privacy section */
	
	section = [[QSection alloc] init];
	[section setTitle:@"Privacy"];
	
	/* whitelist cookies */
	
	QRadioElement *whitelistCookies = [self yesNoRadioElementWithDefault:(![host isDefault])];
	[whitelistCookies setTitle:@"Allow persistent cookies"];
	val = [host setting:HOST_SETTINGS_KEY_WHITELIST_COOKIES];
	if (val == nil)
		val = HOST_SETTINGS_DEFAULT;
	[whitelistCookies setSelectedValue:val];
	[section setFooter:[NSString stringWithFormat:@"Allow %@ to permanently store cookies and local storage databases", ([host isDefault] ? @"hosts" : @"this host")]];
	[section addElement:whitelistCookies];
	
	[root addSection:section];
	
	/* security section */
	
	section = [[QSection alloc] init];
	[section setTitle:@"Security"];
	
	/* tls version */
	
	NSMutableArray *i = [[NSMutableArray alloc] init];
	if (![host isDefault])
		[i addObject:@"Default"];
	[i addObjectsFromArray:@[ @"TLS 1.2 Only", @"TLS 1.2, 1.1, or 1.0" ]];

	QRadioElement *tls = [[QRadioElement alloc] initWithItems:i selected:0];
	
	i = [[NSMutableArray alloc] init];
	if (![host isDefault])
		[i addObject:HOST_SETTINGS_DEFAULT];
	[i addObjectsFromArray:@[ HOST_SETTINGS_TLS_12, HOST_SETTINGS_TLS_AUTO ]];
	[tls setValues:i];
	
	i = [[NSMutableArray alloc] init];
	if (![host isDefault])
		[i addObject:@"Default"];
	[i addObjectsFromArray:@[ @"TLS 1.2", @"Any TLS" ]];
	[tls setShortItems:i];
	
	[tls setTitle:@"TLS version"];
	NSString *tlsval = [host setting:HOST_SETTINGS_KEY_TLS];
	if (tlsval == nil)
		[tls setSelectedValue:HOST_SETTINGS_DEFAULT];
	else
		[tls setSelectedValue:tlsval];
	[section setFooter:[NSString stringWithFormat:@"Minimum version of TLS required by %@ to negotiate HTTPS connections", ([host isDefault] ? @"hosts" : @"this host")]];
	[section addElement:tls];
	[root addSection:section];
	
	section = [[QSection alloc] init];
	
	/* content policy */
	
	i = [[NSMutableArray alloc] init];
	if (![host isDefault])
		[i addObject:@"Default"];
	[i addObjectsFromArray:@[ @"Open (normal browsing mode)", @"No XHR/WebSockets/Video connections", @"Strict (no JavaScript, video, etc.)" ]];
	
	QRadioElement *csp = [[QRadioElement alloc] initWithItems:i selected:0];
	
	i = [[NSMutableArray alloc] init];
	if (![host isDefault])
		[i addObject:HOST_SETTINGS_DEFAULT];
	[i addObjectsFromArray:@[ HOST_SETTINGS_CSP_OPEN, HOST_SETTINGS_CSP_BLOCK_CONNECT, HOST_SETTINGS_CSP_STRICT ]];
	[csp setValues:i];
	
	i = [[NSMutableArray alloc] init];
	if (![host isDefault])
		[i addObject:@"Default"];
	[i addObjectsFromArray:@[ @"Open", @"No-Connect", @"Strict" ]];
	[csp setShortItems:i];
	
	[csp setTitle:@"Content policy"];
	NSString *cspval = [host setting:HOST_SETTINGS_KEY_CSP];
	if (cspval == nil)
		[csp setSelectedValue:HOST_SETTINGS_DEFAULT];
	else
		[csp setSelectedValue:cspval];
	[section setFooter:[NSString stringWithFormat:@"Restrictions on resources loaded from web pages%@", ([host isDefault] ? @"" : @" at this host")]];
	[section addElement:csp];
	[root addSection:section];
	
	/* mixed-mode resources */
	
	section = [[QSection alloc] init];
	QRadioElement *allowmixedmode = [self yesNoRadioElementWithDefault:(![host isDefault])];
	[allowmixedmode setTitle:@"Allow mixed-mode resources"];
	val = [host setting:HOST_SETTINGS_KEY_ALLOW_MIXED_MODE];
	if (val == nil)
		val = HOST_SETTINGS_DEFAULT;
	[allowmixedmode setSelectedValue:val];
	[section addElement:allowmixedmode];
	[section setFooter:[NSString stringWithFormat:@"Allow %@ to load page resources from non-HTTPS hosts (useful for RSS readers and other aggregators)", ([host isDefault] ? @"HTTPS hosts" : @"this HTTPS host")]];
	[root addSection:section];

	/* block external lan requests */
	
	section = [[QSection alloc] init];
	
	QRadioElement *exlan = [self yesNoRadioElementWithDefault:(![host isDefault])];
	[exlan setTitle:@"Block external LAN requests"];
	val = [host setting:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS];
	if (val == nil)
		val = HOST_SETTINGS_DEFAULT;
	[exlan setSelectedValue:val];
	[section addElement:exlan];
	[section setFooter:[NSString stringWithFormat:@"Resources loaded from %@ will be blocked from loading page elements or making requests to LAN hosts (192.168.0.0/16, 172.16.0.0/12, etc.)", ([host isDefault] ? @"hosts" : @"this host")]];
	[root addSection:section];
	
	QuickDialogController *qdc = [QuickDialogController controllerForRoot:root];
	
	[qdc setWillDisappearCallback:^{
		if (![host isDefault])
			[host setHostname:[hostname textValue]];
		
		[host setSetting:HOST_SETTINGS_KEY_TLS toValue:(NSString *)[tls selectedValue]];
		[host setSetting:HOST_SETTINGS_KEY_CSP toValue:(NSString *)[csp selectedValue]];
		[host setSetting:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS toValue:(NSString *)[exlan selectedValue]];
		[host setSetting:HOST_SETTINGS_KEY_WHITELIST_COOKIES toValue:(NSString *)[whitelistCookies selectedValue]];
		[host setSetting:HOST_SETTINGS_KEY_ALLOW_MIXED_MODE toValue:(NSString *)[allowmixedmode selectedValue]];

		[host save];
		[HostSettings persist];
	}];
	
	[[self navigationController] pushViewController:qdc animated:YES];
	self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Hosts" style:UIBarButtonItemStylePlain target:nil action:nil];
}

- (QRadioElement *)yesNoRadioElementWithDefault:(BOOL)withDefault
{
	NSMutableArray *items = [[NSMutableArray alloc] init];
	if (withDefault)
		[items addObject:@"Default"];
	[items addObjectsFromArray:@[ @"Yes", @"No" ]];
	
	QRadioElement *opt = [[QRadioElement alloc] initWithItems:items selected:0];
	
	NSMutableArray *vals = [[NSMutableArray alloc] init];
	if (withDefault)
		[vals addObject:HOST_SETTINGS_DEFAULT];
	[vals addObjectsFromArray:@[ HOST_SETTINGS_VALUE_YES, HOST_SETTINGS_VALUE_NO ]];
	[opt setValues:vals];
	
	return opt;
}

@end
