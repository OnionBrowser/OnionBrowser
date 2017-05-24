/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import <UIKit/UIKit.h>
#import "QRCodeReaderViewController.h"

@interface BridgeCustomViewController : UIViewController <QRCodeReaderDelegate>

- (void)qrscan;
- (void)save;
- (void)cancel;

- (void)exitModal;

@end
