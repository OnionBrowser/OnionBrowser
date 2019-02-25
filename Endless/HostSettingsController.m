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
	
	self.title = NSLocalizedString(@"Host Settings", nil);
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addHost:)];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil) style:UIBarButtonItemStyleDone target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];
	
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
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Host Settings", nil) message:NSLocalizedString(@"Enter the host/domain to define settings for", nil) preferredStyle:UIAlertControllerStyleAlert];
	[alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
		textField.placeholder = @"example.com";
		
		if (self->firstMatch != nil)
			textField.text = self->firstMatch;
	}];
	
	UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"OK action") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
		UITextField *host = alertController.textFields.firstObject;
		if (host && ![[host text] isEqualToString:@""]) {
			HostSettings *hs = [[HostSettings alloc] initForHost:[host text] withDict:nil];
			[hs save];
			[HostSettings persist];
			self->_sortedHosts = nil;
			
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
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_HOST rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"Host/domain", nil)];
			[row setValue:HOST_SETTINGS_HOST_DEFAULT_LABEL];
			[section setFooterTitle:NSLocalizedString(@"These settings will be used as defaults for all hosts unless overridden", nil)];
			[section addFormRow:row];
		}
		else {
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_HOST rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"Host/domain", nil)];
			[row setValue:[host hostname]];
			[row.cellConfigAtConfigure setObject:@"example.com" forKey:@"textField.placeholder"];
			[row.cellConfigAtConfigure setObject:@(NSTextAlignmentRight) forKey:@"textField.textAlignment"];
			[section setFooterTitle:NSLocalizedString(@"These settings will apply to this host and all hosts under it (e.g., \"example.com\" will apply to example.com and www.example.com)", nil)];
			[section addFormRow:row];
		}
	}
	
	/* privacy section */
	{
		XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
		[section setTitle:NSLocalizedString(@"Privacy", nil)];
		[form addFormSection:section];

		/* whitelist cookies */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_WHITELIST_COOKIES rowType:XLFormRowDescriptorTypeSelectorActionSheet title:NSLocalizedString(@"Allow persistent cookies", nil)];
			[self setYesNoSelectorOptionsForSetting:HOST_SETTINGS_KEY_WHITELIST_COOKIES host:host row:row withDefault:(![host isDefault])];
			
			[section setFooterTitle:([host isDefault]
                                     ? NSLocalizedString(@"Allow hosts to permanently store cookies and local storage databases", nil)
                                     : NSLocalizedString(@"Allow this host to permanently store cookies and local storage databases", nil))
			];
			[section addFormRow:row];
			[form addFormSection:section];
		}
		
		/* allow webRTC */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_ALLOW_WEBRTC rowType:XLFormRowDescriptorTypeSelectorActionSheet title:NSLocalizedString(@"Allow WebRTC", nil)];
			[self setYesNoSelectorOptionsForSetting:HOST_SETTINGS_KEY_ALLOW_WEBRTC host:host row:row withDefault:(![host isDefault])];
			
			section = [XLFormSectionDescriptor formSection];
			[section setTitle:@""];
			[section setFooterTitle:([host isDefault]
						 ? NSLocalizedString(@"Allow hosts to access WebRTC functions", nil)
						 : NSLocalizedString(@"Allow this host to access WebRTC functions", nil))
			];
			[section addFormRow:row];
			[form addFormSection:section];
		}
		
		/* universal link protection */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_UNIVERSAL_LINK_PROTECTION rowType:XLFormRowDescriptorTypeSelectorActionSheet title:NSLocalizedString(@"Universal Link Protection", nil)];
			[self setYesNoSelectorOptionsForSetting:HOST_SETTINGS_KEY_UNIVERSAL_LINK_PROTECTION host:host row:row withDefault:(![host isDefault])];
			
			section = [XLFormSectionDescriptor formSection];
			[section setTitle:@""];
			[section setFooterTitle:([host isDefault]
						 ? NSLocalizedString(@"Handle tapping on links in a non-standard way to avoid possibly opening external applications", nil)
						 : NSLocalizedString(@"Handle tapping on links on pages from this host in a non-standard way to avoid possibly opening external applications", nil))
			];
			[section addFormRow:row];
			[form addFormSection:section];
		}

	}
	
	/* security section */
	{
		XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
		[section setTitle:NSLocalizedString(@"Security", nil)];
		[form addFormSection:section];

		/* ignore TLS errors */
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"allow_tls_error_ignore"])
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_IGNORE_TLS_ERRORS rowType:XLFormRowDescriptorTypeSelectorActionSheet title:NSLocalizedString(@"Ignore TLS errors", nil)];

			XLFormOptionsObject *yes = [XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_VALUE_YES displayText:NSLocalizedString(@"Yes", nil)];
			XLFormOptionsObject *no = [XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_VALUE_NO displayText:NSLocalizedString(@"No", nil)];

			// This value is always "NO", except, when the user set the global setting
			// "allow_tls_error_ignore" to YES *and* they surfed to a site with an error
			// *and* the selected "ignore" on the following error alert.
			[row setSelectorOptions:@[no]];

			NSString *val = [host setting:HOST_SETTINGS_KEY_IGNORE_TLS_ERRORS];
			[row setValue:[val isEqualToString:HOST_SETTINGS_VALUE_YES] ? yes : no];

			[section addFormRow:row];
		}
		
		/* tls version */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_TLS rowType:XLFormRowDescriptorTypeSelectorActionSheet title:NSLocalizedString(@"TLS version", nil)];
			
			NSMutableArray *opts = [[NSMutableArray alloc] init];
			if (![host isDefault])
				[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_DEFAULT displayText:NSLocalizedString(@"(Use Default)", nil)]];
			[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_TLS_12 displayText:NSLocalizedString(@"TLS 1.2 Only", nil)]];
			[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_TLS_AUTO displayText:NSLocalizedString(@"TLS 1.2, 1.1, or 1.0", nil)]];
			[row setSelectorOptions:opts];
			
			NSString *val = [host setting:HOST_SETTINGS_KEY_TLS];
			if (val == nil)
				val = HOST_SETTINGS_DEFAULT;
			
			for (XLFormOptionsObject *opt in opts)
				if ([[opt valueData] isEqualToString:val])
					[row setValue:opt];
			
			[section setFooterTitle:([host isDefault]
                                     ? NSLocalizedString(@"Minimum version of TLS required by hosts to negotiate HTTPS connections", nil)
                                     : NSLocalizedString(@"Minimum version of TLS required by this host to negotiate HTTPS connections", nil))];
			[section addFormRow:row];
		}
		
		/* content policy */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_CSP rowType:XLFormRowDescriptorTypeSelectorActionSheet title:NSLocalizedString(@"Content policy", nil)];
			
			NSMutableArray *opts = [[NSMutableArray alloc] init];
			if (![host isDefault])
				[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_DEFAULT displayText:NSLocalizedString(@"(Use Default)", nil)]];
			[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_CSP_OPEN displayText:NSLocalizedString(@"Open (normal browsing mode)", nil)]];
			[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_CSP_BLOCK_CONNECT displayText:NSLocalizedString(@"No XHR/WebSocket/Video connections", nil)]];
			[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_CSP_STRICT displayText:NSLocalizedString(@"Strict (no JavaScript, video, etc.)", nil)]];
			[row setSelectorOptions:opts];
			
			NSString *val = [host setting:HOST_SETTINGS_KEY_CSP];
			if (val == nil)
				val = HOST_SETTINGS_DEFAULT;
			
			for (XLFormOptionsObject *opt in opts)
				if ([[opt valueData] isEqualToString:val])
					[row setValue:opt];
			
			section = [XLFormSectionDescriptor formSection];
			[section setTitle:@""];
			[section setFooterTitle:([host isDefault]
                                     ? NSLocalizedString(@"Restrictions on resources loaded from web pages", nil)
                                     : NSLocalizedString(@"Restrictions on resources loaded from web pages at this host", nil))];
			[form addFormSection:section];
			[section addFormRow:row];
		}
		
		/* whitelist cookies */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_ALLOW_MIXED_MODE rowType:XLFormRowDescriptorTypeSelectorActionSheet title:NSLocalizedString(@"Allow mixed-mode resources", nil)];
			[self setYesNoSelectorOptionsForSetting:HOST_SETTINGS_KEY_ALLOW_MIXED_MODE host:host row:row withDefault:(![host isDefault])];
			
			section = [XLFormSectionDescriptor formSection];
			[section setTitle:@""];
			[section setFooterTitle:([host isDefault]
                                     ? NSLocalizedString(@"Allow HTTPS hosts to load page resources from non-HTTPS hosts (useful for RSS readers and other aggregators)", nil)
                                     : NSLocalizedString(@"Allow this HTTPS host to load page resources from non-HTTPS hosts (useful for RSS readers and other aggregators)", nil))];
			[form addFormSection:section];
			[section addFormRow:row];
		}

		/* block external lan requests */
        /*
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS rowType:XLFormRowDescriptorTypeSelectorActionSheet title:NSLocalizedString(@"Block external LAN requests", nil)];
			[self setYesNoSelectorOptionsForSetting:HOST_SETTINGS_KEY_BLOCK_LOCAL_NETS host:host row:row withDefault:(![host isDefault])];
			
			section = [XLFormSectionDescriptor formSection];
			[section setTitle:@""];
			[section setFooterTitle:([host isDefault]
                                     ? NSLocalizedString(@"Resources loaded from external hosts will be blocked from loading page elements or making requests to LAN hosts (192.168.0.0/16, 172.16.0.0/12, etc.)", nil)
                                     : NSLocalizedString(@"Resources loaded from this host will be blocked from loading page elements or making requests to LAN hosts (192.168.0.0/16, 172.16.0.0/12, etc.)", nil))];
			[form addFormSection:section];
			[section addFormRow:row];
		}
         */
	}
	
	/* misc section */
	{
		XLFormSectionDescriptor *section = [XLFormSectionDescriptor formSection];
		[section setTitle:NSLocalizedString(@"Other", nil)];
		[form addFormSection:section];
		
		/* user agent */
		{
			XLFormRowDescriptor *row = [XLFormRowDescriptor formRowDescriptorWithTag:HOST_SETTINGS_KEY_USER_AGENT rowType:XLFormRowDescriptorTypeText title:NSLocalizedString(@"User Agent", nil)];
			[row setValue:[host setting:HOST_SETTINGS_KEY_USER_AGENT]];
			[section setFooterTitle:[NSString stringWithFormat:NSLocalizedString(@"Custom user-agent string, or blank to use the default", nil)]];
			[section addFormRow:row];
		}
	}

	HostSettingsXLFormViewController *formController = [[HostSettingsXLFormViewController alloc] initWithForm:form];
	[formController setDisappearCallback:^(HostSettingsXLFormViewController *form) {
		if (![host isDefault])
			[host setHostname:[[form formValues] objectForKey:HOST_SETTINGS_KEY_HOST]];
		
		for (NSString *key in [[HostSettings defaults] allKeys]) {
			XLFormOptionsObject *opt = [[form formValues] objectForKey:key];
			if (opt)
				[host setSetting:key toValue:(NSString *)[opt valueData]];
		}
		
		[host save];
		[HostSettings persist];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[[NSNotificationCenter defaultCenter] postNotificationName:HOST_SETTINGS_CHANGED object:nil];
		});
	}];

	[[self navigationController] pushViewController:formController animated:YES];
	self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Hosts", nil) style:UIBarButtonItemStylePlain target:nil action:nil];
}

- (void)setYesNoSelectorOptionsForSetting:(NSString *)key host:(HostSettings *)host row:(XLFormRowDescriptor *)row withDefault:(BOOL)withDefault
{
	NSMutableArray *opts = [[NSMutableArray alloc] init];
	if (withDefault)
		[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_DEFAULT displayText:NSLocalizedString(@"(Use Default)", nil)]];
	[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_VALUE_YES displayText:NSLocalizedString(@"Yes", no)]];
	[opts addObject:[XLFormOptionsObject formOptionsObjectWithValue:HOST_SETTINGS_VALUE_NO displayText:NSLocalizedString(@"No", no)]];
	[row setSelectorOptions:opts];

	NSString *val = [host setting:key];
	if (val == nil)
		val = HOST_SETTINGS_DEFAULT;

	for (XLFormOptionsObject *opt in opts)
		if ([[opt valueData] isEqualToString:val])
			[row setValue:opt];
}

@end
