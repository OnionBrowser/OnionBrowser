/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import "BridgeViewController.h"
#import "AppDelegate.h"
#import "BridgeCustomViewController.h"
#import "Ipv6Tester.h"
#import "OBSettingsConstants.h"

#ifdef __OBJC__
#import "OnionBrowser-Swift.h"
#import <Tor/Tor.h>
#endif


@interface BridgeViewController ()

@end

@implementation BridgeViewController
@synthesize backButton;

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = @"Network Configuration";

	//AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	//if (![appDelegate.tor didFirstConnect]) {
		backButton = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:self action:@selector(finishSaveClose)];
		self.navigationItem.rightBarButtonItem = backButton;
	//}
}

- (void)viewDidUnload {
	[super viewDidUnload];
}

/*- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return (IS_IPAD) || (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}*/

- (void)goBack {
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
    // TODO re-enable ipv4/ipv6?
    //return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0) {
		// configure custom bridges, obfs4, meek-azure, meek-amazon, disable bridges
		return 5;
    // TODO re-enable ipv4/ipv6?
    //} else if (section == 1) {
    //    return 4;
    } else {
        return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
	if (section == 0) {
        return @"Bridges\n\nBridges are Tor relays that help circumvent censorship. You can try bridges if Tor is blocked by your ISP; each type of bridge uses a different method to avoid censorship: if one type does not work, try using a different one.\n\nYou may use the provided bridges below or obtain bridges at bridges.torproject.org.";
    // TODO re-enable ipv4/ipv6?
	//} else if (section == 1) {
    //    return @"IPv4 / IPv6 Connection Settings\n\nThis is an advanced setting and can result in connection issues.\n\nIf you are using a VPN and have issues connecting, try changing this to IPv4.";
    } else {
		return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    NSInteger bridgeSetting = [settings integerForKey:USE_BRIDGES];
    //NSInteger ipv4v6Setting = [settings integerForKey:IPV4V6];
    NSArray *bridgeArr = [settings stringArrayForKey:CUSTOM_BRIDGES];
    NSInteger numCustomBridges = [bridgeArr count];

	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithFrame:CGRectZero];
	}

    cell.accessoryType = UITableViewCellAccessoryNone;

	if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"No Bridges: Directly Connect to Tor";
            if (bridgeSetting == USE_BRIDGES_NONE || ((bridgeSetting == USE_BRIDGES_CUSTOM) && numCustomBridges == 0)) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Provided Bridges: obfs4";
            if (bridgeSetting == USE_BRIDGES_OBFS4) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Provided Bridges: meek-amazon";
            if (bridgeSetting == USE_BRIDGES_MEEKAMAZON) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
		} else if (indexPath.row == 3) {
			cell.textLabel.text = @"Provided Bridges: meek-azure";
            if (bridgeSetting == USE_BRIDGES_MEEKAZURE) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
		} else if (indexPath.row == 4) {
			cell.textLabel.text = @"Custom Bridges";
            if ((bridgeSetting == USE_BRIDGES_CUSTOM) && numCustomBridges > 0) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
		}
    // TODO re-enable ipv4/ipv6?
    /*} else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Automatic IPv4/IPv6";
            if (ipv4v6Setting == IPV4V6_AUTO) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Always Use IPv4";
            if (ipv4v6Setting == IPV4V6_V4ONLY) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Always Use IPv6";
            if (ipv4v6Setting == IPV4V6_V6ONLY) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
        } else if (indexPath.row == 3) {
            cell.textLabel.text = @"Force Dual Stack (Prefer IPv4)";
            if (ipv4v6Setting == IPV4V6_FORCEDUAL) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            }
        }
    */}

	return cell;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [settings setInteger:USE_BRIDGES_NONE forKey:USE_BRIDGES];
            [settings removeObjectForKey:CUSTOM_BRIDGES];
        } else if (indexPath.row == 1) {
            [settings setInteger:USE_BRIDGES_OBFS4 forKey:USE_BRIDGES];
            [settings removeObjectForKey:CUSTOM_BRIDGES];
        } else if (indexPath.row == 2) {
            [settings setInteger:USE_BRIDGES_MEEKAMAZON forKey:USE_BRIDGES];
            [settings removeObjectForKey:CUSTOM_BRIDGES];
        } else if (indexPath.row == 3) {
            [settings setInteger:USE_BRIDGES_MEEKAZURE forKey:USE_BRIDGES];
            [settings removeObjectForKey:CUSTOM_BRIDGES];
        } else if (indexPath.row == 4) {
            BridgeCustomViewController *customBridgeVC = [[BridgeCustomViewController alloc] init];
            [self.navigationController pushViewController:customBridgeVC animated:YES];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [settings setInteger:IPV4V6_AUTO forKey:IPV4V6];
        } else if (indexPath.row == 1) {
            [settings setInteger:IPV4V6_V4ONLY forKey:IPV4V6];
        } else if (indexPath.row == 2) {
            [settings setInteger:IPV4V6_V6ONLY forKey:IPV4V6];
        } else if (indexPath.row == 3) {
            [settings setInteger:IPV4V6_FORCEDUAL forKey:IPV4V6];
        }
    }
    [settings synchronize];

    [tableView reloadData];
}







- (void)save:(NSString *)bridgeLines {
    [self.tableView reloadData];

	//[appDelegate updateTorrc];
}

- (void)finishSaveClose{
	[self finishSave:nil final:YES];

}
- (void)finishSave:(NSString *)extraMsg final:(Boolean)isFinal {
    OnionManager *onion = [OnionManager singleton];
    
    if (onion.torHasConnected) {
        NSString *msg = @"Bridge changes require an app restart; press \"Quit App\" and reopen the app to use the new connection settings.\n\nPressing 'Continue Anyway' will use your previous settings until you restart the app.";
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bridges Saved" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Continue anyway" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Quit app" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            exit(0);
        }]];
        [self presentViewController:alert animated:YES completion:NULL];
    }

    /*
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    NSArray *bridgeArr = [settings stringArrayForKey:CUSTOM_BRIDGES];
    NSInteger numCustomBridges = [bridgeArr count];

    if ((![appDelegate.tor didFirstConnect]) && isFinal) {
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

    } else if ([appDelegate.tor didFirstConnect]) {

        NSString *pluralize = @" is";
        if (numCustomBridges > 1) {
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

	} else if (extraMsg != nil) {
		UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Updated" message:extraMsg preferredStyle:UIAlertControllerStyleAlert];
		[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}]];
		[self presentViewController:alert animated:YES completion:NULL];
	}
    */
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
