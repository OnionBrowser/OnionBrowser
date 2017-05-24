/*
 * Onion Browser
 * Copyright (c) 2012-2017 Mike Tigas
 *
 * This file is part of Onion Browser. See LICENSE file for redistribution terms.
 */

#import "BridgeCustomViewController.h"
#import "AppDelegate.h"
#import "UIPlaceHolderTextView.h"
#import "OBSettingsConstants.h"


@interface BridgeCustomViewController ()

@end

@implementation BridgeCustomViewController

- (void)viewDidLoad {
    [super viewDidLoad];

	self.title = @"Custom Bridges";

    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save)];
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
	self.navigationItem.leftBarButtonItem = cancelButton;
	self.navigationItem.rightBarButtonItem = saveButton;

    UIBarButtonItem *flexibleSpace = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *qrButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera target:self action:@selector(qrscan)];
	//if ([QRCodeReader isAvailable]) {
	if (YES) {
		self.navigationController.toolbarHidden=NO;
		self.toolbarItems = [NSArray arrayWithObjects: flexibleSpace, qrButton, nil];
    }

    CGSize size = [UIScreen mainScreen].bounds.size;
    CGRect txtFrame = [UIScreen mainScreen].bounds;
    txtFrame.origin.y = 0;
    txtFrame.origin.x = 0;
    txtFrame.size = size;

    UIPlaceHolderTextView *txtView = [[UIPlaceHolderTextView alloc] initWithFrame:txtFrame];
    txtView.font = [UIFont systemFontOfSize:11];
    txtView.text = [self bridgesToBridgeLines];
    NSString *placeholderText = @"In another browser, visit https://bridges.torproject.org/ and pick \"Get Bridges\". Use the 'Advanced Options' section; 'obfs4' Pluggable Transports are recommended. (Do not select IPv6.)";
    if ([QRCodeReader isAvailable]) {
      placeholderText = [placeholderText stringByAppendingString:@"\n\nYou can tap the 'camera' icon below to use the QR code from the website, or manually copy-and-paste the \"bridge lines\" here:"];
    } else {
      placeholderText = [placeholderText stringByAppendingString:@" Then copy-and-paste the \"bridge lines\" here:"];
    }
    placeholderText = [placeholderText stringByAppendingString:@"\n\ni.e.:\nobfs4 172.0.0.1:1234 123456319E89E5C6223052AA525A192AFBC85D55 cert=GGGS1TX4R81m3r0HBl79wKy1OtPPNR2CZUIrHjkRg65Vc2VR8fOyo64f9kmT1UAFG7j0HQ iat-mode=0\n\nobfs4 172.0.0.2:4567 ABCDEF825B3B9EA6A98C83AC41F7099D67007EA5 cert=xpmQtKUqQ/6v5X7ijgYE/f03+l2/EuQ1dexjyUhh16wQlu/cpXUGalmhDIlhuiQPNEKmKw iat-mode=0\n\nobfs4 172.0.0.3:7890 098765AB960E5AC6A629C729434FF84FB5074EC2 cert=VW5f8+IBUWpPFxF+rsiVy2wXkyTQG7vEd+rHeN2jV5LIDNu8wMNEOqZXPwHdwMVEBdqXEw iat-mode=0"];
    txtView.placeholder = placeholderText;
    txtView.placeholderColor = [UIColor grayColor];
    txtView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    txtView.tag = 50;
    [self.view addSubview: txtView];
}

- (NSString *)bridgesToBridgeLines {
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    NSArray *bridgeArr = [settings stringArrayForKey:CUSTOM_BRIDGES];
    
    if (bridgeArr == nil) {
        return @"";
    }

    NSMutableString *output = [[NSMutableString alloc] init];
    for (NSString *bridge in bridgeArr) {
        [output appendFormat:@"%@\n", bridge];
    }
    return [NSString stringWithString:output];
}

- (void)qrscan {
  if ([QRCodeReader supportsMetadataObjectTypes:@[AVMetadataObjectTypeQRCode]]) {
    static QRCodeReaderViewController *reader = nil;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
      reader                        = [QRCodeReaderViewController new];
      reader.modalPresentationStyle = UIModalPresentationFormSheet;
    });
    reader.delegate = self;

    [reader setCompletionWithBlock:^(NSString *resultAsString) {
      NSLog(@"Completion with result: %@", resultAsString);
    }];

    [self presentViewController:reader animated:YES completion:NULL];
  }
  else {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:@"Camera access was not granted or QRCode scanning is not supported by your device." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:NULL];
  }
}
#pragma mark - QRCodeReader Delegate Methods

- (void)reader:(QRCodeReaderViewController *)reader didScanResult:(NSString *)result {
    [self dismissViewControllerAnimated:YES completion:^{

        /* if ([result containsString:@"obfs3"] |[result containsString:@"scramblesuit"]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Unsupported Pluggable Transport" message:@"At least one bridge line you scanned contains an 'obfs3' or 'scramblesuit' bridge.\n\nOnion Browser does not currently support these bridges. Please select 'obfs4' or 'none' for 'Do you need a Pluggable Transport?' when getting bridges on the Tor bridge site." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:NULL];
        } else { */
            NSString *realResult = result;


            // I think QRCode used to return the exact string we wanted (newline delimited),
            // but now it returns a JSON-like array ['bridge1', 'bridge2'...] so parse that out.
            if ([result containsString:@"['"] || [result containsString:@"[\""]) {
              // Actually, the QRCode is json-like. It uses single-quote string array, where JSON only
              // allows double-quote.
              realResult = [realResult stringByReplacingOccurrencesOfString:@"['" withString:@"[\""];
              realResult = [realResult stringByReplacingOccurrencesOfString:@"', '" withString:@"\", \""];
              realResult = [realResult stringByReplacingOccurrencesOfString:@"','" withString:@"\",\""];
              realResult = [realResult stringByReplacingOccurrencesOfString:@"']" withString:@"\"]"];

              #ifdef DEBUG
              NSLog(@"realResult: %@", realResult);
              #endif

              NSError *e = nil;
              NSArray *resultLines = [NSJSONSerialization JSONObjectWithData:[realResult dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&e];

              #ifdef DEBUG
              NSLog(@"resultLines: %@", resultLines);
              #endif

              if (resultLines) {
                realResult = [resultLines componentsJoinedByString:@"\n"];
              } else {
                NSLog(@"%@", e);
                NSLog(@"%@", realResult);
              }
            }

            UIPlaceHolderTextView *txtView = (UIPlaceHolderTextView *)[self.view viewWithTag:50];
            txtView.text = realResult;

            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bridges Scanned" message:@"Successfully scanned bridges. Please press 'Save' and restart the app for these changes to take effect." preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:NULL];
        /* } */
    }];
}

- (void)readerDidCancel:(QRCodeReaderViewController *)reader {
    [self dismissViewControllerAnimated:YES completion:NULL];
}




- (void)save {
    NSUserDefaults *settings = [NSUserDefaults standardUserDefaults];
    [settings removeObjectForKey:CUSTOM_BRIDGES];

    UIPlaceHolderTextView *txtView = (UIPlaceHolderTextView *)[self.view viewWithTag:50];
    NSString *txt = [txtView.text stringByReplacingOccurrencesOfString:@"[ ]+"
                                                       withString:@" "
                                                          options:NSRegularExpressionSearch
                                                            range:NSMakeRange(0, txtView.text.length)];

    Boolean shouldSaveAndExit = YES;

    NSMutableArray *bridgeArr = [[NSMutableArray alloc] init];
    for (NSString *line in [txt componentsSeparatedByString:@"\n"]) {
        NSString *newLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([newLine isEqualToString:@""] || [newLine hasPrefix:@"//"] || [newLine hasPrefix:@"#"]) {
            // skip empty lines
        } else {
            [bridgeArr addObject:newLine];
        }
    }
    
    [settings setInteger:USE_BRIDGES_CUSTOM forKey:USE_BRIDGES];
    [settings setObject:(NSArray *)[bridgeArr copy] forKey:CUSTOM_BRIDGES];

    [settings synchronize];
    if (shouldSaveAndExit) {
        [self exitModal];
    }
}

- (void)cancel {
    [self exitModal];
}



- (void)exitModal {
    [self dismissViewControllerAnimated:YES completion:NULL];
    /*
  AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
  NSManagedObjectContext *ctx = appDelegate.managedObjectContext;

  NSMutableDictionary *settings = appDelegate.getSettings;
  [settings setObject:[NSNumber numberWithInteger:TOR_BRIDGES_CUSTOM] forKey:@"bridges"];
  [appDelegate saveSettings:settings];

  if (![appDelegate.tor didFirstConnect]) {
      UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Please Restart App" message:@"Onion Browser will now close. Please start the app again to retry the Tor connection with the newly-configured bridges.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)" preferredStyle:UIAlertControllerStyleAlert];
      [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
          [appDelegate wipeAppData];
          exit(0);
      }]];
      [self presentViewController:alert animated:YES completion:NULL];
      // App will die after this, so don't enable network.
  } else {
	  [appDelegate updateTorrc];

	  NSFetchRequest *request = [[NSFetchRequest alloc] init];
      NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:ctx];
      [request setEntity:entity];

      NSArray *newResults = [ctx executeFetchRequest:request error:nil];
      if (newResults == nil) {}

      if ([newResults count] > 0) {
          NSString *pluralize = @" is";
          if ([newResults count] > 1) {
              pluralize = @"s are";
          }
          UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bridges" message:[NSString stringWithFormat:@"%ld bridge%@ configured.You may need to quit the app and restart it to change the connection method.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)", (unsigned long)[newResults count], pluralize] preferredStyle:UIAlertControllerStyleAlert];
          [alert addAction:[UIAlertAction actionWithTitle:@"Continue anyway" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
              // User has opted to continue normally, so tell Tor to reconnect
              [appDelegate recheckObfsproxy];
              [appDelegate.tor enableNetwork];
              [appDelegate.tor hupTor];
			  self.navigationController.toolbarHidden=YES;
			  [self.navigationController popViewControllerAnimated:YES];
          }]];
          [alert addAction:[UIAlertAction actionWithTitle:@"Restart app" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
              [appDelegate wipeAppData];
              exit(0);
          }]];
          [self presentViewController:alert animated:YES completion:NULL];

      } else {
          UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Bridges Disabled" message:@"No bridges are configured, so bridge connection mode is disabled. If you previously had bridges, you may need to quit the app and restart it to change the connection method.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)" preferredStyle:UIAlertControllerStyleAlert];
          [alert addAction:[UIAlertAction actionWithTitle:@"Continue anyway" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
              // User has opted to continue normally, so tell Tor to reconnect
              [appDelegate recheckObfsproxy];
              [appDelegate.tor enableNetwork];
              [appDelegate.tor hupTor];
			  self.navigationController.toolbarHidden=YES;
			  [self.navigationController popViewControllerAnimated:YES];
          }]];
          [alert addAction:[UIAlertAction actionWithTitle:@"Restart app" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
              [appDelegate wipeAppData];
              exit(0);
          }]];
          [self presentViewController:alert animated:YES completion:NULL];
      }
  }*/
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
