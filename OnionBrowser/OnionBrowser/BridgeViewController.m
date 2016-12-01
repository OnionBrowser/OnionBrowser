#import "BridgeViewController.h"
#import "AppDelegate.h"
#import "BridgeCustomViewController.h"
#import "Bridge.h"

@interface BridgeViewController ()

@end

@implementation BridgeViewController
@synthesize backButton;

- (void)viewDidLoad {
	[super viewDidLoad];

	self.title = @"Bridge Configuration";
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
		return 3;
    } else if (section == 1) {
        return 1;
    } else if (section == 2) {
        return 1;
    } else {
        return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
	if (section == 0) {
        NSString *bridgeMsg = @"Bridges are Tor relays that help circumvent censorship. You can try bridges if Tor is blocked by your ISP; each type of bridge uses a different method to avoid censorship: if one type does not work, try using a different one.\n\nYou may use the provided bridges below or obtain bridges at bridges.torproject.org.";

		AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		NSUInteger numBridges = [appDelegate numBridgesConfigured];

		NSMutableDictionary *settings = appDelegate.getSettings;
		NSInteger bridgeSetting = [[settings valueForKey:@"bridges"] integerValue];
		if (bridgeSetting == TOR_BRIDGES_OBFS4) {
			bridgeMsg = [bridgeMsg stringByAppendingString:@"\n\nCurrently Using Provided obfs4 Bridges"];
		} else if (bridgeSetting == TOR_BRIDGES_MEEKAMAZON) {
			bridgeMsg = [bridgeMsg stringByAppendingString:@"\n\nCurrently Using Provided Meek (Amazon) Bridge"];
		} else if (bridgeSetting == TOR_BRIDGES_MEEKAZURE) {
			bridgeMsg = [bridgeMsg stringByAppendingString:@"\n\nCurrently Using Provided Meek (Azure) Bridge"];
		} else if (numBridges == 0) {
			bridgeMsg = [bridgeMsg stringByAppendingString:@"\n\nNo bridges currently configured\n"];
		} else {
			bridgeMsg = [bridgeMsg stringByAppendingString:[NSString stringWithFormat:@"\n\nCurrently Using %ld Custom Bridge",
															(unsigned long)numBridges]];
			if (numBridges > 1) {
				bridgeMsg = [bridgeMsg stringByAppendingString:@"s"];
			}
		}


        bridgeMsg = [bridgeMsg stringByAppendingString:@"\nChoose a new config:\n"];
		return bridgeMsg;
	} else
		return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"Cell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithFrame:CGRectZero];
	}

	if (indexPath.section == 0) {
		if (indexPath.row == 0) {
			cell.textLabel.text = @"Provided Bridges: obfs4";
		} else if (indexPath.row == 1) {
			cell.textLabel.text = @"Provided Bridges: meek-amazon";
		} else if (indexPath.row == 2) {
			cell.textLabel.text = @"Provided Bridges: meek-azure";
		}
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Enter Custom Bridges";
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Disable Bridges";
        }
    }

	return cell;
}



- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	NSMutableDictionary *settings = appDelegate.getSettings;
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [self save:[Bridge defaultObfs4]];
			[settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_OBFS4] forKey:@"bridges"];
			[appDelegate saveSettings:settings];

            [self finishSave:@"NOTE: Onion Browser chooses the provided obfs4 bridges in a random order. You can force the app to use other obfs4 bridges by choosing the \"Provided Bridges: obfs4\" option again."];
        } else if (indexPath.row == 1) {
            [self save:[Bridge defaultMeekAmazon]];
			[settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_MEEKAMAZON] forKey:@"bridges"];
			[appDelegate saveSettings:settings];

            [self finishSave:nil];
        } else if (indexPath.row == 2) {
            [self save:[Bridge defaultMeekAzure]];
			[settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_MEEKAZURE] forKey:@"bridges"];
			[appDelegate saveSettings:settings];

			[self finishSave:nil];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            BridgeCustomViewController *customBridgeVC = [[BridgeCustomViewController alloc] init];
            [self.navigationController pushViewController:customBridgeVC animated:YES];
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            [Bridge clearBridges];
			[settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_NONE] forKey:@"bridges"];
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
        if (numBridges == 0) {
            msg = @"Bridge changes require an app restart. Onion Browser will now quit; reopen the app to connect without bridges.";
            if (extraMsg != nil) {
			         msg = [msg stringByAppendingString:@"\n\n"];
			         msg = [msg stringByAppendingString:extraMsg];
            }
        } else {
            msg = @"Bridge changes require an app restart. Onion Browser will now quit; reopen the app to use the new bridge connections.\n\n(If you restart and the app does not connect, press the \"settings\" button and try other bridges.)";
            if (extraMsg != nil) {
			         msg = [msg stringByAppendingString:@"\n\n"];
			         msg = [msg stringByAppendingString:extraMsg];
            }
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
        if (numBridges == 0) {
            msg = @"Bridges have been disabled. Bridge changes may require an app restart; press \"Quit App\" and reopen the app to connect without bridges.";
        } else {
            msg = [NSString stringWithFormat:@"%ld bridge%@ configured. Bridge changes may require an app restart; press \"Quit App\" and reopen the app to use the new bridge connections.\n\n(If you restart and the app does not connect, press the \"settings\" button and try other bridges.)", (unsigned long)numBridges, pluralize];
        }

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
