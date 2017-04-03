// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "SettingsTableViewController.h"
#import "AppDelegate.h"
#import "BridgeViewController.h"
#import "Ipv6Tester.h"

@interface SettingsTableViewController ()

@end

@implementation SettingsTableViewController
@synthesize backButton;

- (void)viewDidLoad {
    [super viewDidLoad];

	self.title = @"Settings";

	backButton = [[UIBarButtonItem alloc] initWithTitle:@"Save" style:UIBarButtonItemStyleDone target:self action:@selector(goBack)];
    self.navigationItem.leftBarButtonItem = backButton;
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
    return 7;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else if (section == 1) {
        // Active Content
        return 3;
    } else if (section == 2) {
        // Cookies
        return 3;
    } else if (section == 3) {
        // UA Spoofing
        return 5;
    } else if (section == 4) {
        // DNT header
        return 2;
    } else if (section == 5) {
        // SSL
        return 3;
    } else if (section == 6) {
        // Bridges
        return 1;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if (section == 0)
        return @"Home Page";
    else if (section == 1)
        return @"Active Content Blocking\n(Scripts, Media, Ajax, WebSockets, etc)\n★ 'Block Ajax…' Mode Recommended.";
    else if (section == 2)
        return @"Cookies";
    else if (section == 3) {
        NSString *devicename;
        if (IS_IPAD) {
            devicename = @"iPad";
        } else {
            devicename = @"iPhone";
        }
        return [NSString stringWithFormat:@"User-Agent Spoofing\n★ 'Standard' does not hide your device info (%@, iOS %@).\n★ 'Normalized' is recommended & masks your actual device/version.\n★ Win/Mac options try to mask that you use a iOS device.", devicename, [[UIDevice currentDevice] systemVersion]];
    } else if (section == 4)
        return @"Do Not Track (DNT) Header\nThis does not prevent sites from tracking you: this only tells sites that you prefer not being tracked for customzied advertising.";
    else if (section == 5)
        return @"Minimum SSL/TLS protocol\nNewer TLS protocols are more secure, but might not be supported by all sites.";
	else if (section == 6) {
		NSString *bridgeMsg = @"Network settings:\nUse bridges if your Internet Service Provider (ISP) blocks connections to Tor. Adjust IPv4/IPV6 settings for unusual network configurations.\n";

		AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
		NSUInteger numBridges = [appDelegate numBridgesConfigured];
		NSMutableDictionary *settings = appDelegate.getSettings;
		NSInteger bridgeSetting = [[settings valueForKey:@"bridges"] integerValue];
    NSInteger ipv4v6Setting = [[settings valueForKey:@"tor_ipv4v6"] integerValue];

		if (bridgeSetting == TOR_BRIDGES_OBFS4) {
			bridgeMsg = [bridgeMsg stringByAppendingString:@"\nCurrently Using Provided obfs4 Bridges"];
		} else if (bridgeSetting == TOR_BRIDGES_MEEKAMAZON) {
			bridgeMsg = [bridgeMsg stringByAppendingString:@"\nCurrently Using Provided Meek (Amazon) Bridge"];
		} else if (bridgeSetting == TOR_BRIDGES_MEEKAZURE) {
			bridgeMsg = [bridgeMsg stringByAppendingString:@"\nCurrently Using Provided Meek (Azure) Bridge"];
		} else if (numBridges > 0) {
			bridgeMsg = [bridgeMsg stringByAppendingString:[NSString stringWithFormat:@"\nCurrently Using %ld Custom Bridge",
															(unsigned long)numBridges]];
			if (numBridges > 1) {
				bridgeMsg = [bridgeMsg stringByAppendingString:@"s"];
			}
		} else {
			bridgeMsg = [bridgeMsg stringByAppendingString:@"\nNo Bridges: Directly Connecting to Tor"];
    }

		if (ipv4v6Setting == OB_IPV4V6_AUTO) {
      bridgeMsg = [bridgeMsg stringByAppendingString:@"\nAutodetecting IP stack: "];
			NSInteger ipv6_status = [Ipv6Tester ipv6_status];
      if (ipv6_status == TOR_IPV6_CONN_ONLY) {
				bridgeMsg = [bridgeMsg stringByAppendingString:@"IPv6-only detected"];
			} else if (ipv6_status == TOR_IPV6_CONN_DUAL) {
				bridgeMsg = [bridgeMsg stringByAppendingString:@"Dual-stack IPv4+IPv6 detected"];
			} else if (ipv6_status == TOR_IPV6_CONN_FALSE) {
				bridgeMsg = [bridgeMsg stringByAppendingString:@"IPv4-only detected"];
			} else {
				bridgeMsg = [bridgeMsg stringByAppendingString:@"Could not detect IP stack state. Using IPv4-only."];
			}
		} else if (ipv4v6Setting == OB_IPV4V6_V4ONLY) {
      bridgeMsg = [bridgeMsg stringByAppendingString:@"\nForcing IPv4-only."];
    } else if (ipv4v6Setting == OB_IPV4V6_V6ONLY) {
      bridgeMsg = [bridgeMsg stringByAppendingString:@"\nForcing IPv6-only."];
	} else if (ipv4v6Setting == OB_IPV4V6_FORCEDUAL) {
		bridgeMsg = [bridgeMsg stringByAppendingString:@"\nForcing dual-stack (prefer IPv4)"];
	}
		return bridgeMsg;
	} else
        return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithFrame:CGRectZero];
    }

    if(indexPath.section == 0) {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings2 = appDelegate.getSettings;
        cell.textLabel.text = [settings2 objectForKey:@"homepage"];
    } else if (indexPath.section == 1) {
        // Active Content
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger csp_setting = [[settings valueForKey:@"javascript"] integerValue];

        if (indexPath.row == 0) {
            cell.textLabel.text = @"Block Ajax/Media/WebSockets";
            if (csp_setting == CONTENTPOLICY_BLOCK_CONNECT) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Block All Active Content";
            if (csp_setting == CONTENTPOLICY_STRICT) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Allow All (DANGEROUS)";
            if (csp_setting == CONTENTPOLICY_PERMISSIVE) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if(indexPath.section == 2) {
        // Cookies
        NSHTTPCookie *cookie;
        NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        for (cookie in [storage cookies]) {
            [storage deleteCookie:cookie];
        }

        NSHTTPCookieAcceptPolicy currentCookieStatus = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookieAcceptPolicy];
        NSUInteger cookieStatusSection = 0;
        if (currentCookieStatus == NSHTTPCookieAcceptPolicyAlways) {
            cookieStatusSection = 0;
        } else if (currentCookieStatus == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain) {
            cookieStatusSection = 1;
        } else {
            cookieStatusSection = 2;
        }

        if (indexPath.row == cookieStatusSection) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }

        if (indexPath.row == 0) {
            cell.textLabel.text = @"Allow All";
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Block Third-Party";
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Disable Cookies";
        }
    } else if (indexPath.section == 3) {
        // User-Agent
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger spoofUserAgent = [[settings valueForKey:@"uaspoof"] integerValue];

        if (indexPath.row == 0) {
            cell.textLabel.text = @"Standard";
            if (spoofUserAgent == UA_SPOOF_NO) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Normalized iPhone (iOS Safari)";
            if (spoofUserAgent == UA_SPOOF_IPHONE) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Normalized iPad (iOS Safari)";
            if (spoofUserAgent == UA_SPOOF_IPAD) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 3) {
            cell.textLabel.text = @"Windows 7 (NT 6.1), Firefox 45";
            if (spoofUserAgent == UA_SPOOF_WIN7_TORBROWSER) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 4) {
            cell.textLabel.text = @"Mac OS X 10.12.4, Safari 10.1";
            if (spoofUserAgent == UA_SPOOF_SAFARI_MAC) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if (indexPath.section == 4) {
        // DNT
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger dntHeader = [[settings valueForKey:@"dnt"] integerValue];

        if (indexPath.row == 0) {
            cell.textLabel.text = @"No Preference Sent";
            if (dntHeader == DNT_HEADER_UNSET) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Tell Websites Not To Track";
            if (dntHeader == DNT_HEADER_NOTRACK) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if (indexPath.section == 5) {
        // SSL
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger dntHeader = [[settings valueForKey:@"tlsver"] integerValue];

        if (indexPath.row == 0) {
            cell.textLabel.text = @"SSL v3 (INSECURE)";
            if (dntHeader == X_TLSVER_ANY) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"TLS 1.0+";
            if (dntHeader == X_TLSVER_TLS1) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"TLS 1.2 only";
            if (dntHeader == X_TLSVER_TLS1_2_ONLY) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if (indexPath.section == 6) {
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.text = @"Bridges & Network Connection";
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == 0) {
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings2 = appDelegate.getSettings;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Home Page" message:@"Leave blank to use default\nOnion Browser home page." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *_Nonnull action) {
            AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
            NSMutableDictionary *settings = appDelegate.getSettings;



            if ([[alert.textFields.firstObject text] length] == 0) {
                [settings setValue:@"onionbrowser:home" forKey:@"homepage"]; // DEFAULT HOMEPAGE
            } else {
                NSString *h = [alert.textFields.firstObject text];
                if ( (![h hasPrefix:@"http:"]) && (![h hasPrefix:@"https:"]) && (![h hasPrefix:@"onionbrowser:"]) && (![h hasPrefix:@"about:"]) )
                    h = [NSString stringWithFormat:@"http://%@", h];
                [settings setValue:h forKey:@"homepage"];
            }
            [appDelegate saveSettings:settings];
            [self.tableView reloadData];
        }]];
        [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
          textField.autocorrectionType = UITextAutocorrectionTypeNo;
          [textField setKeyboardType:UIKeyboardTypeURL];
          textField.text = [settings2 objectForKey:@"homepage"];
        }];


        [self presentViewController:alert animated:YES completion:NULL];
    } else if (indexPath.section == 1) {
        // Active Content
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:CONTENTPOLICY_BLOCK_CONNECT] forKey:@"javascript"];
            [appDelegate saveSettings:settings];

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Experimental Feature" message:@"Blocking of Ajax/XHR/WebSocket requests is experimental. Some websites may not work if these dynamic requests are blocked; but these dynamic requests can leak your identity." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:NULL];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:CONTENTPOLICY_STRICT] forKey:@"javascript"];
            [appDelegate saveSettings:settings];

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Experimental Feature" message:@"Blocking all active content is an experimental feature.\n\nDisabling active content makes it harder for websites to identify your device, but websites will be able to tell that you are blocking scripts. This may be identifying information if you are the only user that blocks scripts.\n\nSome websites may not work if active content is blocked.\n\nBlocking may cause Onion Browser to crash when loading script-heavy websites." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:NULL];
        } else if (indexPath.row == 2) {
            [settings setObject:[NSNumber numberWithInteger:CONTENTPOLICY_PERMISSIVE] forKey:@"javascript"];
            [appDelegate saveSettings:settings];

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Security Warning" message:@"The 'Allow All' setting is UNSAFE and only recommended if a trusted site requires Ajax or WebSockets.\n\nWebSocket requests happen outside of Tor and will unmask your real IP address." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:NULL];
        }
    } else if(indexPath.section == 2) {
        // Cookies
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:COOKIES_ALLOW_ALL] forKey:@"cookies"];
            [appDelegate saveSettings:settings];
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:COOKIES_BLOCK_THIRDPARTY] forKey:@"cookies"];
            [appDelegate saveSettings:settings];
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];
        } else if (indexPath.row == 2) {
            [settings setObject:[NSNumber numberWithInteger:COOKIES_BLOCK_ALL] forKey:@"cookies"];
            [appDelegate saveSettings:settings];
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyNever];
        }
    } else if (indexPath.section == 3) {
        // User-Agent
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        //NSString* secretAgent = [appDelegate.appWebView.myWebView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
        //NSLog(@"%@", secretAgent);

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_NO] forKey:@"uaspoof"];
            [appDelegate saveSettings:settings];
        } else {
            if (indexPath.row == 1) {
                [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_IPHONE] forKey:@"uaspoof"];
                [appDelegate saveSettings:settings];
            } else if (indexPath.row == 2) {
                [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_IPAD] forKey:@"uaspoof"];
                [appDelegate saveSettings:settings];
            } else if (indexPath.row == 3) {
                [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_WIN7_TORBROWSER] forKey:@"uaspoof"];
                [appDelegate saveSettings:settings];
            } else if (indexPath.row == 4) {
                [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_SAFARI_MAC] forKey:@"uaspoof"];
                [appDelegate saveSettings:settings];
            }

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:@"User Agent spoofing enabled.\n\nNote that scripts, active content, and other iOS features may still identify your browser.\n\nFor 'desktop' options, mobile or tablet websites may not work properly." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:NULL];
        }
    } else if (indexPath.section == 4) {
        // DNT
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:DNT_HEADER_UNSET] forKey:@"dnt"];
            [appDelegate saveSettings:settings];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:DNT_HEADER_NOTRACK] forKey:@"dnt"];
            [appDelegate saveSettings:settings];
        }
    } else if (indexPath.section == 5) {
        // TLS
        AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:X_TLSVER_ANY] forKey:@"tlsver"];
            [appDelegate saveSettings:settings];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:X_TLSVER_TLS1] forKey:@"tlsver"];
            [appDelegate saveSettings:settings];
        } else if (indexPath.row == 2) {
            [settings setObject:[NSNumber numberWithInteger:X_TLSVER_TLS1_2_ONLY] forKey:@"tlsver"];
            [appDelegate saveSettings:settings];
        }
    } else if (indexPath.section == 6) {
        BridgeViewController *bridgesVC = [[BridgeViewController alloc] initWithStyle:UITableViewStyleGrouped];
		[self.navigationController pushViewController:bridgesVC animated:YES];
    }
    [tableView reloadData];
}
@end
