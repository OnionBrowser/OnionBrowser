/*
 * Endless
 * Copyright (c) 2015-2017 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "AppDelegate.h"
#import "HostSettings.h"
#import "HostSettingsController.h"

#import "XLForm.h"

@interface HostSettingsXLFormViewController : XLFormViewController
@property (copy, nonatomic) void (^disappearCallback)(HostSettingsXLFormViewController *);
@end

@implementation HostSettingsXLFormViewController

- (void)viewWillDisappear:(BOOL)animated
{
	if (self.disappearCallback)
		self.disappearCallback(self);
	
	[super viewWillDisappear:animated];
}
@end


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
	HostSettings *host = [HostSettings forHost:thost];
	
	XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:[host hostname]];

	/* hostname */
	{
		XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
		[form addFormSection:section];
		
		if ([host isDefault]) {
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_HOST rowType:XLFormRowDescriptorTypeInfo title:@"Host/domain"];
			[row setValue:HOST_SETTINGS_HOST_DEFAULT_LABEL];
			[section setFooterTitle:@"These settings will be used as defaults for all hosts unless overridden"];
			[section addFormRow:row];
		}
		else {
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_HOST rowType:XLFormRowDescriptorTypeText title:@"Host/domain"];
			[row setValue:[host hostname]];
			[row.cellConfigAtConfigure setObject:@"example.com" forKey:@"textField.placeholder"];
			[row.cellConfigAtConfigure setObject:@(NSTextAlignmentRight) forKey:@"textField.textAlignment"];
			[section setFooterTitle:@"These settings will apply to this host and all hosts under it (e.g., \"example.com\" will apply to example.com and www.example.com)"];
			[section addFormRow:row];
		}
	}
	
	/* privacy section */
	{
		XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
		[section setTitle:@"Privacy"];
		[form addFormSection:section];

		/* whitelist cookies */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_WHITELIST_COOKIES rowType:XLFormRowDescriptorTypeSelectorActionSheet title:@"Allow persistent cookies"];
			[self setYesNoSelectorOptionsForSetting:HOST_SETTINGS_KEY_WHITELIST_COOKIES host:host row:row withDefault:(![host isDefault])];
			
			[section setFooterTitle:[NSString stringWithFormat:@"Allow %@ to permanently store cookies and local storage databases", ([host isDefault] ? @"hosts" : @"this host")]];
			[section addFormRow:row];
		}
	}
	
	/* security section */
	{
		XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
		[section setTitle:@"Security"];
		[form addFormSection:section];
		
		/* tls version */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_TLS rowType:XLFormRowDescriptorTypeSelectorActionSheet title:@"TLS version"];
			
			NSMutableArray *opts = [[NSMutableArray alloc] init];
			if (![host isDefault])
				[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_DEFAULT displayText:@"(Use Default)"]];
			[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_TLS_12 displayText:@"TLS 1.2 Only"]];
			[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_TLS_AUTO displayText:@"TLS 1.2, 1.1, or 1.0"]];
			[row setSelectorOptions:opts];
			
			NSString *val = [host setting:HOST_SETTINGS_KEY_TLS];
			if (val == nil)
				val = HOST_SETTINGS_DEFAULT;
			
			for (XLFormOptionsObject *opt in opts)
				if ([[opt valueData] isEqualToString:val])
					[row setValue:opt];
			
			[section setFooterTitle:[NSString stringWithFormat:@"Minimum version of TLS required by %@ to negotiate HTTPS connections", ([host isDefault] ? @"hosts" : @"this host")]];
			[section addFormRow:row];
		}
		
		/* content policy */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_CSP rowType:XLFormRowDescriptorTypeSelectorActionSheet title:@"Content policy"];
			
			NSMutableArray *opts = [[NSMutableArray alloc] init];
			if (![host isDefault])
				[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_DEFAULT displayText:@"(Use Default)"]];
			[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_CSP_OPEN displayText:@"Open (normal browsing mode)"]];
			[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_CSP_BLOCK_CONNECT displayText:@"No XHR/WebSockets/Video connections"]];
			[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_CSP_STRICT displayText:@"Strict (no JavaScript, video, etc.)"]];
			[row setSelectorOptions:opts];
			
			NSString *val = [host setting:HOST_SETTINGS_KEY_CSP];
			if (val == nil)
				val = HOST_SETTINGS_DEFAULT;
			
			for (XLFormOptionsObject *opt in opts)
				if ([[opt valueData] isEqualToString:val])
					[row setValue:opt];
			
			section = [XLFormSectionDescriptor formSection];
			[section setTitle:@""];
			[section setFooterTitle:[NSString stringWithFormat:@"Restrictions on resources loaded from web pages%@", ([host isDefault] ? @"" : @" at this host")]];
			[form addFormSection:section];
			[section addFormRow:row];
		}
		
		/* whitelist cookies */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_ALLOW_MIXED_MODE rowType:XLFormRowDescriptorTypeSelectorActionSheet title:@"Allow mixed-mode resources"];
			[self setYesNoSelectorOptionsForSetting:HOST_SETTINGS_KEY_ALLOW_MIXED_MODE host:host row:row withDefault:(![host isDefault])];
			
			section = [XLFormSectionDescriptor formSection];
			[section setTitle:@""];
			[section setFooterTitle:[NSString stringWithFormat:@"Allow %@ to load page resources from non-HTTPS hosts (useful for RSS readers and other aggregators)", ([host isDefault] ? @"HTTPS hosts" : @"this HTTPS host")]];
			[form addFormSection:section];
			[section addFormRow:row];
		}

		/* block external lan requests */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS rowType:XLFormRowDescriptorTypeSelectorActionSheet title:@"Block external LAN requests"];
			[self setYesNoSelectorOptionsForSetting:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS host:host row:row withDefault:(![host isDefault])];
			
			section = [XLFormSectionDescriptor formSection];
			[section setTitle:@""];
			[section setFooterTitle:[NSString stringWithFormat:@"Resources loaded from %@ will be blocked from loading page elements or making requests to LAN hosts (192.168.0.0/16, 172.16.0.0/12, etc.)", ([host isDefault] ? @"external hosts" : @"this host")]];
			[form addFormSection:section];
			[section addFormRow:row];
		}
	}
	
	/* misc section */
	{
		XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
		[section setTitle:@"Other"];
		[form addFormSection:section];
		
		/* user agent */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_USER_AGENT rowType:XLFormRowDescriptorTypeText title:@"User Agent"];
			[row setValue:[host setting:HOST_SETTINGS_KEY_USER_AGENT]];
			[section setFooterTitle:[NSString stringWithFormat:@"Custom user-agent string, or blank to use the default"]];
			[section addFormRow:row];
		}
	}

	HostSettingsXLFormViewController *formController = [[HostSettingsXLFormViewController alloc] initWithForm:form];
	[formController setDisappearCallback:^(HostSettingsXLFormViewController *form) {
		if (![host isDefault])
			[host setHostname:[[form formValues] objectForKey:HOST_SETTINGS_KEY_HOST]];
		
		NSArray *keys = @[
			HOST_SETTINGS_KEY_ALLOW_MIXED_MODE,
			HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS,
			HOST_SETTINGS_KEY_CSP,
			HOST_SETTINGS_KEY_TLS,
			HOST_SETTINGS_KEY_WHITELIST_COOKIES,
			HOST_SETTINGS_KEY_USER_AGENT,
		];
		
		for (NSString *key in keys) {
			XLFormOptionsObject *opt = [[form formValues] objectForKey:key];
			if (opt)
				[host setSetting:key toValue:(NSString *)[opt valueData]];
		}
		
		[host save];
		[HostSettings persist];
	}];

	[[self navigationController] pushViewController:formController animated:YES];
	self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Hosts" style:UIBarButtonItemStylePlain target:nil action:nil];
}

- (void)setYesNoSelectorOptionsForSetting:(NSString *)key host:(HostSettings *)host row:(XLFormRowDescriptor *)row withDefault:(BOOL)withDefault
{
	NSMutableArray *opts = [[NSMutableArray alloc] init];
	if (withDefault)
		[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_DEFAULT displayText:@"(Use Default)"]];
	[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_VALUE_YES displayText:@"Yes"]];
	[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_VALUE_NO displayText:@"No"]];
	[row setSelectorOptions:opts];

	NSString *val = [host setting:key];
	if (val == nil)
		val = HOST_SETTINGS_DEFAULT;

	for (XLFormOptionsObject *opt in opts)
		if ([[opt valueData] isEqualToString:val])
			[row setValue:opt];
}

@end
