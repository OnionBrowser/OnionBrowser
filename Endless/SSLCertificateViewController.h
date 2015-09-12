/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>

#import "OrderedDictionary.h"
#import "SSLCertificate.h"

@interface SSLCertificateViewController : UITableViewController <UITableViewDelegate> {
	MutableOrderedDictionary *certInfo;
}

@property (strong) SSLCertificate *certificate;

- (id)initWithSSLCertificate:(SSLCertificate *)cert;

@end
