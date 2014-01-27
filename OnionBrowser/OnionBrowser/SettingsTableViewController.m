//
//  SettingsTableViewController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 5/2/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "SettingsTableViewController.h"
#import "AppDelegate.h"
#import "BridgeTableViewController.h"

@interface SettingsTableViewController ()

@end

@implementation SettingsTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (IS_IPAD) || (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
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
        return 2;
    } else if (section == 2) {
        // Cookies
        return 3;
    } else if (section == 3) {
        // UA Spoofing
        return 3;
    } else if (section == 4) {
        // Pipelining
        return 2;
    } else if (section == 5) {
        // DNT header
        return 2;
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
        return @"Active Content\n(Javascript, Plugins, Multimedia, External Fonts, XHR, WebSockets)";
    else if (section == 2)
        return @"Cookies\n(Changing Will Clear Cookies)";
    else if (section == 3)
        return @"User-Agent Spoofing\n* iOS Safari provides better mobile website compatibility.\n* Windows 7 string is recommended for privacy and uses the same string as the official Tor Browser Bundle.";
    else if (section == 4)
        return @"HTTP Pipelining\n(Disable if you have issues with images on some websites)";
    else if (section == 5)
        return @"DNT (Do Not Track) Header";
    else if (section == 6)
        return @"Tor Bridges\nSet up bridges if you have issues connecting to Tor. Remove all bridges to go back standard connection mode.\nSee http://onionbrowser.com/help/ for instructions.";
    else
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
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings2 = appDelegate.getSettings;
        cell.textLabel.text = [settings2 objectForKey:@"homepage"];
    } else if (indexPath.section == 1) {
        // Active Content
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger javascriptEnabled = [[settings valueForKey:@"javascript"] integerValue];

        if (indexPath.row == 0) {
            cell.textLabel.text = @"Allow All (Better Compatibility)";
            if (javascriptEnabled == YES) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Block All (Better Security)";
            if (javascriptEnabled == NO) {
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
            cell.textLabel.text = @"Block All";
        }
    } else if (indexPath.section == 3) {
        // User-Agent
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger spoofUserAgent = [[settings valueForKey:@"uaspoof"] integerValue];
        
        if (indexPath.row == 0) {
            cell.textLabel.text = @"No Spoofing: iOS Safari";
            if (spoofUserAgent == UA_SPOOF_NO) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Windows 7 (NT 6.1), Firefox 17";
            if (spoofUserAgent == UA_SPOOF_WIN7_TORBROWSER) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Mac OS X 10.8.4, Safari 6.0";
            if (spoofUserAgent == UA_SPOOF_SAFARI_MAC) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if (indexPath.section == 4) {
        // Pipelining
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger usePipelining = [[settings valueForKey:@"pipelining"] integerValue];

        if (indexPath.row == 0) {
            cell.textLabel.text = @"Enabled (Better Performance)";
            if (usePipelining == YES) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Disabled (Better Compatibility)";
            if (usePipelining == NO) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if (indexPath.section == 5) {
        // DNT
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        NSInteger dntHeader = [[settings valueForKey:@"dnt"] integerValue];

        if (indexPath.row == 0) {
            cell.textLabel.text = @"No Header";
            if (dntHeader == DNT_HEADER_UNSET) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Opt Out Of Tracking";
            if (dntHeader == DNT_HEADER_NOTRACK) {
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            } else {
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
        }
    } else if (indexPath.section == 6) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:appDelegate.managedObjectContext];
        [request setEntity:entity];
        
        NSError *error = nil;
        NSMutableArray *mutableFetchResults = [[appDelegate.managedObjectContext executeFetchRequest:request error:&error] mutableCopy];
        if (mutableFetchResults == nil) {
            // Handle the error.
        }

        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        NSUInteger numBridges = [mutableFetchResults count];
        if (numBridges == 0) {
            cell.textLabel.text = @"Not Using Bridges";
        } else {
            cell.textLabel.text = [NSString stringWithFormat:@"%d Bridges Configured",
                                   numBridges];
        }
    }
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if(indexPath.section == 0) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings2 = appDelegate.getSettings;

        UIAlertView * alert = [[UIAlertView alloc] initWithTitle:@"Home Page" message:@"Leave blank to use default\nhome page with Tor Check." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Save",nil];
        alert.alertViewStyle = UIAlertViewStylePlainTextInput;
        
        UITextField *textField = [alert textFieldAtIndex:0];
        [textField setKeyboardType:UIKeyboardTypeURL];
        textField.text = [settings2 objectForKey:@"homepage"];
        
        [alert show];
    } else if (indexPath.section == 1) {
        // Active Content
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:JAVASCRIPT_ENABLED] forKey:@"javascript"];
            [appDelegate saveSettings:settings];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:JAVASCRIPT_DISABLED] forKey:@"javascript"];
            [appDelegate saveSettings:settings];
            if ([[[UIDevice currentDevice] systemVersion] compare:@"6.0" options:NSNumericSearch] == NSOrderedAscending) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"iOS 5 Warning"
                                                                message:[NSString stringWithFormat:@"You appear to be running a version of iOS earlier than 6.0. Support for blocking active content is only partially supported in iOS 5.1. You may have reduced security or the app may crash more often."]
                                                               delegate:nil
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
                [alert show];
            }
            UIAlertView *alert2 = [[UIAlertView alloc] initWithTitle:@"Experimental Feature"
                                                            message:[NSString stringWithFormat:@"Active Content Blocking is an experimental feature.\n\nWhile disabling scripts makes it harder for websites to identify your device, the website may be able to tell if you are disabling scripts. This may be identifying information if you are the only user accessing a website while disabling scripts.\n\nSome websites may not work if active content is blocked.\n\nBlocking may cause Onion Browser to crash when loading script-heavy websites."]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert2 show];
        }
    } else if(indexPath.section == 2) {
        // Cookies
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:COOKIES_ALLOW_ALL] forKey:@"uaspoof"];
            [appDelegate saveSettings:settings];
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:COOKIES_BLOCK_THIRDPARTY] forKey:@"uaspoof"];
            [appDelegate saveSettings:settings];
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain];
        } else if (indexPath.row == 2) {
            [settings setObject:[NSNumber numberWithInteger:COOKIES_BLOCK_ALL] forKey:@"uaspoof"];
            [appDelegate saveSettings:settings];
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyNever];
        }
    } else if (indexPath.section == 3) {
        // User-Agent
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_NO] forKey:@"uaspoof"];
            [appDelegate saveSettings:settings];
        } else {
            if (indexPath.row == 1) {
                [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_WIN7_TORBROWSER] forKey:@"uaspoof"];
                [appDelegate saveSettings:settings];
            } else if (indexPath.row == 2) {
                [settings setObject:[NSNumber numberWithInteger:UA_SPOOF_SAFARI_MAC] forKey:@"uaspoof"];
                [appDelegate saveSettings:settings];
            }
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil 
                                                            message:[NSString stringWithFormat:@"User Agent spoofing enabled.\n\nNote that JavaScript cannot be disabled due to framework limitations. Scripts and other iOS features may still identify your browser.\n\nSome mobile or tablet websites may not work properly without the original mobile User Agent."]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK" 
                                                  otherButtonTitles:nil];
            [alert show];
        }
    } else if (indexPath.section == 4) {
        // Pipelining
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:PIPELINING_ON] forKey:@"pipelining"];
            [appDelegate saveSettings:settings];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:PIPELINING_OFF] forKey:@"pipelining"];
            [appDelegate saveSettings:settings];
        }
    } else if (indexPath.section == 5) {
        // DNT
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;

        if (indexPath.row == 0) {
            [settings setObject:[NSNumber numberWithInteger:DNT_HEADER_UNSET] forKey:@"dnt"];
            [appDelegate saveSettings:settings];
        } else if (indexPath.row == 1) {
            [settings setObject:[NSNumber numberWithInteger:DNT_HEADER_NOTRACK] forKey:@"dnt"];
            [appDelegate saveSettings:settings];
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                            message:[NSString stringWithFormat:@"Onion Browser will now send the 'DNT: 1' header. Note that because only very new browsers send this optional header, this opt-in feature may allow websites to uniquely identify you."]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK" 
                                                  otherButtonTitles:nil];
            [alert show];
        }
    } else if (indexPath.section == 6) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];

        BridgeTableViewController *bridgesVC = [[BridgeTableViewController alloc] initWithStyle:UITableViewStylePlain];
        [bridgesVC setManagedObjectContext:[appDelegate managedObjectContext]];
        
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:bridgesVC];
        navController.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [self presentViewController:navController animated:YES completion:nil];
    }
    [tableView reloadData];
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    if (buttonIndex == 1) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        NSMutableDictionary *settings = appDelegate.getSettings;
        
        if ([[[alertView textFieldAtIndex:0] text] length] == 0) {
            [settings setValue:@"onionbrowser:home" forKey:@"homepage"]; // DEFAULT HOMEPAGE
        } else {
            NSString *h = [[alertView textFieldAtIndex:0] text];
            if ( (![h hasPrefix:@"http:"]) && (![h hasPrefix:@"https:"]) && (![h hasPrefix:@"onionbrowser:"]) )
                h = [NSString stringWithFormat:@"http://%@", h];
            [settings setValue:h forKey:@"homepage"];
        }
        [appDelegate saveSettings:settings];
        [self.tableView reloadData];
    }
}





@end
