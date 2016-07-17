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
        NSString *bridgeMsg = @"Bridges are Tor relays that help circumvent censorship. You can try bridges if Tor is blocked by your ISP; each type of bridge uses a different method to avoid censorship: if one type does not work, try using a different one.\n\nYou may use the provided bridges below or obtain bridges at bridges.torproject.org.\n\n(iOS 10 users: obfs4 and meek bridges do not currently work in the iOS 10 beta.)";

		AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
		NSUInteger numBridges = [appDelegate numBridgesConfigured];

		if (numBridges == 0) {
			bridgeMsg = [bridgeMsg stringByAppendingString:@"\n\nNo bridges currently configured\n"];
		} else {
			bridgeMsg = [bridgeMsg stringByAppendingString:[NSString stringWithFormat:@"\n\nCurrently Using %ld Bridge",
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
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            [self save:[self defaultObfs4]];
            [self finishSave:@"NOTE: Onion Browser chooses the provided obfs4 bridges in a random order. You can force the app to use other obfs4 bridges by choosing the \"Provided Bridges: obfs4\" option again."];
        } else if (indexPath.row == 1) {
            [self save:[self defaultMeekAmazon]];
            [self finishSave:nil];
        } else if (indexPath.row == 2) {
            [self save:[self defaultMeekAzure]];
            [self finishSave:nil];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            BridgeCustomViewController *customBridgeVC = [[BridgeCustomViewController alloc] init];
            [self.navigationController pushViewController:customBridgeVC animated:YES];
        }
    } else if (indexPath.section == 2) {
        if (indexPath.row == 0) {
            [self clearBridges];
            [self finishSave:nil];
        }
    }

	[tableView reloadData];
}






- (void)clearBridges {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    NSManagedObjectContext *ctx = appDelegate.managedObjectContext;

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:ctx];
    [request setEntity:entity];

    NSArray *results = [ctx executeFetchRequest:request error:nil];
    if (results == nil) {}
    for (Bridge *bridge in results) {
        [ctx deleteObject:bridge];
    }
    [ctx save:nil];
}

- (void)save:(NSString *)bridgeLines {
    [self clearBridges];

    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    NSManagedObjectContext *ctx = appDelegate.managedObjectContext;

	NSString *txt = [bridgeLines stringByReplacingOccurrencesOfString:@"[ ]+"
															withString:@" "
															   options:NSRegularExpressionSearch
																 range:NSMakeRange(0, bridgeLines.length)];

	for (NSString *line in [txt componentsSeparatedByString:@"\n"]) {
		NSString *newLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if ([newLine isEqualToString:@""]) {
			// skip empty lines
		} else {
            Bridge *newBridge = [NSEntityDescription insertNewObjectForEntityForName:@"Bridge" inManagedObjectContext:ctx];
            [newBridge setConf:newLine];
            NSError *err = nil;
            if (![ctx save:&err]) {
                NSLog(@"Save did not complete successfully. Error: %@", [err localizedDescription]);
            }
        }
	}
    [self.tableView reloadData];

	[appDelegate updateTorrc];
}

- (void)finishSave:(NSString *)extraMsg {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];

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





-(NSString *) defaultObfs4 {
	NSString *defaultLines = @"obfs4 154.35.22.10:41835 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0\n\
obfs4 198.245.60.50:443 752CF7825B3B9EA6A98C83AC41F7099D67007EA5 cert=xpmQtKUqQ/6v5X7ijgYE/f03+l2/EuQ1dexjyUhh16wQlu/cpXUGalmhDIlhuiQPNEKmKw iat-mode=0\n\
obfs4 192.99.11.54:443 7B126FAB960E5AC6A629C729434FF84FB5074EC2 cert=VW5f8+IBUWpPFxF+rsiVy2wXkyTQG7vEd+rHeN2jV5LIDNu8wMNEOqZXPwHdwMVEBdqXEw iat-mode=0\n\
obfs4 109.105.109.165:10527 8DFCD8FB3285E855F5A55EDDA35696C743ABFC4E cert=Bvg/itxeL4TWKLP6N1MaQzSOC6tcRIBv6q57DYAZc3b2AzuM+/TfB7mqTFEfXILCjEwzVA iat-mode=0\n\
obfs4 83.212.101.3:41213 A09D536DD1752D542E1FBB3C9CE4449D51298239 cert=lPRQ/MXdD1t5SRZ9MquYQNT9m5DV757jtdXdlePmRCudUU9CFUOX1Tm7/meFSyPOsud7Cw iat-mode=0\n\
obfs4 104.131.108.182:56880 EF577C30B9F788B0E1801CF7E433B3B77792B77A cert=0SFhfDQrKjUJP8Qq6wrwSICEPf3Vl/nJRsYxWbg3QRoSqhl2EB78MPS2lQxbXY4EW1wwXA iat-mode=0\n\
obfs4 109.105.109.147:13764 BBB28DF0F201E706BE564EFE690FE9577DD8386D cert=KfMQN/tNMFdda61hMgpiMI7pbwU1T+wxjTulYnfw+4sgvG0zSH7N7fwT10BI8MUdAD7iJA iat-mode=0\n\
obfs4 154.35.22.11:49868 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0\n\
obfs4 154.35.22.12:80 00DC6C4FA49A65BD1472993CF6730D54F11E0DBB cert=N86E9hKXXXVz6G7w2z8wFfhIDztDAzZ/3poxVePHEYjbKDWzjkRDccFMAnhK75fc65pYSg iat-mode=0\n\
obfs4 154.35.22.13:443 FE7840FE1E21FE0A0639ED176EDA00A3ECA1E34D cert=fKnzxr+m+jWXXQGCaXe4f2gGoPXMzbL+bTBbXMYXuK0tMotd+nXyS33y2mONZWU29l81CA iat-mode=0\n\
obfs4 154.35.22.10:80 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0\n\
obfs4 154.35.22.10:443 8FB9F4319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0\n\
obfs4 154.35.22.11:443 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0\n\
obfs4 154.35.22.11:80 A832D176ECD5C7C6B58825AE22FC4C90FA249637 cert=YPbQqXPiqTUBfjGFLpm9JYEFTBvnzEJDKJxXG5Sxzrr/v2qrhGU4Jls9lHjLAhqpXaEfZw iat-mode=0\n\
obfs4 154.35.22.9:60873 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0\n\
obfs4 154.35.22.9:80 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0\n\
obfs4 154.35.22.9:443 C73ADBAC8ADFDBF0FC0F3F4E8091C0107D093716 cert=gEGKc5WN/bSjFa6UkG9hOcft1tuK+cV8hbZ0H6cqXiMPLqSbCh2Q3PHe5OOr6oMVORhoJA iat-mode=0";
    NSMutableArray *lines = [NSMutableArray arrayWithArray:[defaultLines componentsSeparatedByCharactersInSet:
        [NSCharacterSet characterSetWithCharactersInString:@"\n"]
    ]];

    // Randomize order of the bridge lines.
    for (int x = 0; x < [lines count]; x++) {
        int randInt = (arc4random() % ([lines count] - x)) + x;
        [lines exchangeObjectAtIndex:x withObjectAtIndex:randInt];
    }
    return [lines componentsJoinedByString:@"\n"];
    // Take a subset of the randomized lines and return it as a new string of bridge lines.
    //NSArray *subset = [lines subarrayWithRange:(NSRange){0, 5}];
    //return [subset componentsJoinedByString:@"\n"];
}
-(NSString *) defaultMeekAmazon {
	return @"meek_lite 0.0.2.0:2 B9E7141C594AF25699E0079C1F0146F409495296 url=https://d2zfqthxsdq309.cloudfront.net/ front=a0.awsstatic.com";
}
-(NSString *) defaultMeekAzure {
	return @"meek_lite 0.0.2.0:3 A2C13B7DFCAB1CBF3A884B6EB99A98067AB6EF44 url=https://az786092.vo.msecnd.net/ front=ajax.aspnetcdn.com";
}

@end
