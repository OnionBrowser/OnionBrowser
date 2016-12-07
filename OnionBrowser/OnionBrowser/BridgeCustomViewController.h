// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <UIKit/UIKit.h>
#import "QRCodeReaderViewController.h"

@interface BridgeCustomViewController : UIViewController <QRCodeReaderDelegate>

- (void)qrscan;
- (void)save;
- (void)cancel;

- (void)exitModal;

@end
