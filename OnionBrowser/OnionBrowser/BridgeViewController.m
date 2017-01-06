// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "BridgeViewController.h"
#import "AppDelegate.h"
#import "BridgeCustomViewController.h"
#import "Bridge.h"
#import "Ipv6Tester.h"

@interface BridgeViewController ()

@end

@implementation BridgeViewController
@synthesize backButton;

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = @"Network Configuration";
	//backButton = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleDone target:self action:@selector(goBack)];
	//self.navigationItem.rightBarButtonItem = backButton;
}

- (void)viewDidUnload {
	[super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (IS_IPAD) || (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)goBack {
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0) {
		// configure custom bridges, obfs4, meek-azure, meek-amazon, disable bridges
		return 5;
    } else if (section == 1) {
        return 3;
    } else {
        return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
	if (section == 0) {
    NSString *bridgeMsg = @"Bridges\n\nBridges are Tor relays that help circumvent censorship. You can try bridges if Tor is blocked by your ISP; each type of bridge uses a different method to avoid censorship: if one type does not work, try using a different one.\n\nYou may use the provided bridges below or obtain bridges at bridges.torproject.org.";

		AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		NSUInteger numBridges = [appDelegate numBridgesConfigured];

		NSMutableDictionary *settings = appDelegate.getSettings;
		NSInteger bridgeSetting = [[settings valueForKey:@"bridges"] integerValue];
		if ((bridgeSetting == TOR_BRIDGES_CUSTOM) && numBridges > 0) {
			bridgeMsg = [bridgeMsg stringByAppendingString:[NSString stringWithFormat:@"\n\nCurrently Using %ld Custom Bridge",
															(unsigned long)numBridges]];
			if (numBridges > 1) {
				bridgeMsg = [bridgeMsg stringByAppendingString:@"s"];
			}
		}
		return bridgeMsg;
	} else if (section == 1) {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSMutableDictionary *settings = appDelegate.getSettings;
    NSInteger ipv4v6Setting = [[settings valueForKey:@"tor_ipv4v6"] integerValue];

    NSString *msg = @"IPv4 / IPv6 Connection Settings\n\nThis is an advanced setting and can result in connection issues.\n\nIf you are using a VPN and have issues connecting, try changing this to IPv4.";

		if (ipv4v6Setting == OB_IPV4V6_AUTO) {
      NSInteger ipv6_status = [Ipv6Tester ipv6_status];
      msg = [msg stringByAppendingString:@"\n\nCurrent autodetect state: "];
			if (ipv6_status == TOR_IPV6_CONN_ONLY) {
				msg = [msg stringByAppendingString:@"IPv6-only detected"];
			} else if (ipv6_status == TOR_IPV6_CONN_DUAL) {
				msg = [msg stringByAppendingString:@"Dual-stack IPv4+IPv6 detected"];
			} else if (ipv6_status == TOR_IPV6_CONN_FALSE) {
				msg = [msg stringByAppendingString:@"IPv4-only detected"];
			} else {
				msg = [msg stringByAppendingString:@"Could not detect IP stack state. Using IPv4-only."];
			}
		}

    return msg;
  } else {
		return nil;
  }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

  AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
  NSUInteger numBridges = [appDelegate numBridgesConfigured];
  NSMutableDictionary *settings = appDelegate.getSettings;
  NSInteger bridgeSetting = [[settings valueForKey:@"bridges"] integerValue];
  NSInteger ipv4v6Setting = [[settings valueForKey:@"tor_ipv4v6"] integerValue];

	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithFrame:CGRectZero];
	}

  cell.accessoryType = UITableViewCellAccessoryNone;

	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			cell.textLabel.text = @"No Bridges: Directly Connect to Tor";
      if (bridgeSetting == TOR_BRIDGES_NONE || ((bridgeSetting == TOR_BRIDGES_CUSTOM) && numBridges == 0)) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
		} else if (indexPath.row == 1) {
			cell.textLabel.text = @"Provided Bridges: obfs4";
      if (bridgeSetting == TOR_BRIDGES_OBFS4) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
		} else if (indexPath.row == 2) {
			cell.textLabel.text = @"Provided Bridges: meek-amazon";
      if (bridgeSetting == TOR_BRIDGES_MEEKAMAZON) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
		} else if (indexPath.row == 3) {
			cell.textLabel.text = @"Provided Bridges: meek-azure";
      if (bridgeSetting == TOR_BRIDGES_MEEKAZURE) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
		} else if (indexPath.row == 4) {
			cell.textLabel.text = @"Custom Bridges";
      if ((bridgeSetting == TOR_BRIDGES_CUSTOM) && numBridges > 0) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
		}
  } else if (indexPath.section == 1) {
		if (indexPath.row == 0) {
			cell.textLabel.text = @"Automatic IPv4/IPv6";
      if (ipv4v6Setting == OB_IPV4V6_AUTO) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
		} else if (indexPath.row == 1) {
			cell.textLabel.text = @"Always Use IPv4";
      if (ipv4v6Setting == OB_IPV4V6_V4ONLY) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
		} else if (indexPath.row == 2) {
			cell.textLabel.text = @"Always Use IPv6";
      if (ipv4v6Setting == OB_IPV4V6_V6ONLY) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
      }
		}
  }

	return cell;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	NSMutableDictionary *settings = appDelegate.getSettings;
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [Bridge clearBridges];
            [settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_NONE] forKey:@"bridges"];
            [appDelegate saveSettings:settings];

            [self finishSave:nil];
        } else if (indexPath.row == 1) {
            [self save:[Bridge defaultObfs4]];
            [settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_OBFS4] forKey:@"bridges"];
            [appDelegate saveSettings:settings];

            [self finishSave:@"NOTE: Onion Browser chooses the provided obfs4 bridges in a random order. You can force the app to use other obfs4 bridges by choosing the \"Provided Bridges: obfs4\" option again."];
        } else if (indexPath.row == 2) {
            [self save:[Bridge defaultMeekAmazon]];
            [settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_MEEKAMAZON] forKey:@"bridges"];
            [appDelegate saveSettings:settings];

            [self finishSave:nil];
        } else if (indexPath.row == 3) {
            [self save:[Bridge defaultMeekAzure]];
            [settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_MEEKAZURE] forKey:@"bridges"];
            [appDelegate saveSettings:settings];

            [self finishSave:nil];
        } else if (indexPath.row == 4) {
            BridgeCustomViewController *customBridgeVC = [[BridgeCustomViewController alloc] init];
            [self.navigationController pushViewController:customBridgeVC animated:YES];
        }
    } else if (indexPath.section == 1) {
      if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:OB_IPV4V6_AUTO] forKey:@"tor_ipv4v6"];
            [appDelegate saveSettings:settings];
		  [self finishSave:nil];
      } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:OB_IPV4V6_V4ONLY] forKey:@"tor_ipv4v6"];
            [appDelegate saveSettings:settings];
		  [self finishSave:nil];
      } else if (indexPath.row == 2) {
            [settings setObject:[NSNumber numberWithInteger:OB_IPV4V6_V6ONLY] forKey:@"tor_ipv4v6"];
            [appDelegate saveSettings:settings];
		  [self finishSave:nil];
      }
    }

    [tableView reloadData];
}







- (void)save:(NSString *)bridgeLines {
	[Bridge updateBridgeLines:bridgeLines];
    [self.tableView reloadData];

	AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate updateTorrc];
}

- (void)finishSave:(NSString *)extraMsg {
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    NSUInteger numBridges = [appDelegate numBridgesConfigured];

    if (![appDelegate.tor didFirstConnect]) {
        NSString *msg;
		msg = @"Network changes require an app restart. Onion Browser will now quit; reopen the app to use the new connection settings.";
		if (extraMsg != nil) {
				 msg = [msg stringByAppendingString:@"\n\n"];
				 msg = [msg stringByAppendingString:extraMsg];
		}

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bridges Saved" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [appDelegate wipeAppData];
            exit(0);
        }]];
        [self presentViewController:alert animated:YES completion:NULL];

    } else {

        NSString *pluralize = @" is";
        if (numBridges > 1) {
            pluralize = @"s are";
        }
        NSString *msg;
        msg = @"Bridge changes may require an app restart; press \"Quit App\" and reopen the app to use the new connection settings.";

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bridges Saved" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Continue anyway" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            // User has opted to continue normally, so tell Tor to reconnect
            [appDelegate recheckObfsproxy];
            [appDelegate.tor enableNetwork];
            [appDelegate.tor hupTor];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Quit app" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [appDelegate wipeAppData];
            exit(0);
        }]];
        [self presentViewController:alert animated:YES completion:NULL];

    }
}

@end
