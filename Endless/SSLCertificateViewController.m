/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "SSLCertificateViewController.h"

@implementation SSLCertificateViewController

#define CI_SIGALG_KEY @"Signature Algorithm"
#define CI_EVORG_KEY @"Extended Validation: Organization"

- (id)initWithSSLCertificate:(SSLCertificate *)cert
{
	self = [super init];
	[self setCertificate:cert];

	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", nil) style:UIBarButtonItemStyleDone target:self.navigationController action:@selector(dismissModalViewControllerAnimated:)];

	certInfo = [[MutableOrderedDictionary alloc] init];
	
	MutableOrderedDictionary *i;
	
	if ([cert negotiatedProtocol]) {
		i = [[MutableOrderedDictionary alloc] init];
		[i setObject:[cert negotiatedProtocolString] forKey:@"Protocol"];
		[i setObject:[cert negotiatedCipherString] forKey:@"Cipher"];
		[certInfo setObject:i forKey:@"Connection Information"];
	}
	
	i = [[MutableOrderedDictionary alloc] init];
	[i setObject:[NSString stringWithFormat:@"%@", [cert version]] forKey:@"Version"];
	[i setObject:[cert serialNumber] forKey:@"Serial Number"];
	[i setObject:[cert signatureAlgorithm] forKey:CI_SIGALG_KEY];
	if ([cert isEV])
		[i setObject:[cert evOrgName] forKey:CI_EVORG_KEY];
	[certInfo setObject:i forKey:@"Certificate Information"];
	
	i = [[MutableOrderedDictionary alloc] init];
	NSMutableDictionary *tcs = [[NSMutableDictionary alloc] initWithDictionary:[cert subject]];
	for (NSString *k in @[ X509_KEY_CN, X509_KEY_O, X509_KEY_OU, X509_KEY_STREET, X509_KEY_L, X509_KEY_ST, X509_KEY_ZIP, X509_KEY_C ]) {
		NSString *val = [tcs objectForKey:k];
		if (val != nil) {
			[i setObject:val forKey:k];
			[tcs removeObjectForKey:k];
		}
	}
	for (NSString *k in [tcs allKeys])
		[i setObject:[[cert subject] objectForKey:k] forKey:k];
	[certInfo setObject:i forKey:@"Issued To"];
	
	NSDateFormatter *df_local = [[NSDateFormatter alloc] init];
	[df_local setTimeZone:[NSTimeZone defaultTimeZone]];
	[df_local setDateFormat:@"yyyy-MM-dd 'at' HH:mm:ss zzz"];

	i = [[MutableOrderedDictionary alloc] init];
	[i setObject:[df_local stringFromDate:[cert validityNotBefore]] forKey:@"Begins On"];
	[i setObject:[df_local stringFromDate:[cert validityNotAfter]] forKey:@"Expires After"];
	[certInfo setObject:i forKey:@"Period of Validity"];

	i = [[MutableOrderedDictionary alloc] init];
	NSMutableDictionary *tci = [[NSMutableDictionary alloc] initWithDictionary:[cert issuer]];
	for (NSString *k in @[ X509_KEY_CN, X509_KEY_O, X509_KEY_OU, X509_KEY_STREET, X509_KEY_L, X509_KEY_ST, X509_KEY_ZIP, X509_KEY_C ]) {
		NSString *val = [tci objectForKey:k];
		if (val != nil) {
			[i setObject:val forKey:k];
			[tci removeObjectForKey:k];
		}
	}
	for (NSString *k in [tci allKeys])
		[i setObject:[[cert issuer] objectForKey:k] forKey:k];
	[certInfo setObject:i forKey:@"Issued By"];
	
	return self;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [certInfo count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [certInfo keyAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	OrderedDictionary *group = [certInfo objectAtIndex:section];
	return [group count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
	
	OrderedDictionary *group = [certInfo objectAtIndex:[indexPath section]];
	NSString *k = [group keyAtIndex:[indexPath row]];
	
	cell.textLabel.text = k;
	cell.detailTextLabel.text = [group objectForKey:k];
	
	if ([k isEqualToString:CI_SIGALG_KEY] && [[self certificate] hasWeakSignatureAlgorithm])
		cell.detailTextLabel.textColor = [UIColor redColor];
	else if ([k isEqualToString:CI_EVORG_KEY])
		cell.detailTextLabel.textColor = [UIColor colorWithRed:0 green:(183.0/255.0) blue:(82.0/255.0) alpha:1.0];

	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
	return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
