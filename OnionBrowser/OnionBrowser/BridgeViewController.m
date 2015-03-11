//
//  BridgeViewController.m
//  OnionBrowser
//
//  Created by Mike Tigas on 3/10/15.
//
//

#import "BridgeViewController.h"
#import "AppDelegate.h"
#import "UIPlaceHolderTextView.h"
#import "Bridge.h"

@interface BridgeViewController ()

@end

@implementation BridgeViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"Bridges";
    UIBarButtonItem *saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save)];
    UIBarButtonItem *qrButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCamera target:self action:@selector(qrscan)];
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    if ([QRCodeReader isAvailable]) {
      [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects:saveButton, qrButton, nil]];
    } else {
      self.navigationItem.rightBarButtonItem = saveButton;
    }

    CGSize size = [UIScreen mainScreen].bounds.size;
    CGRect txtFrame = [[UIScreen mainScreen] applicationFrame];
    txtFrame.origin.y = 0;
    txtFrame.origin.x = 0;
    txtFrame.size = size;

    UIPlaceHolderTextView *txtView = [[UIPlaceHolderTextView alloc] initWithFrame:txtFrame];
    txtView.font = [UIFont systemFontOfSize:11];
    txtView.text = [self bridgesToBridgeLines];
    if ([QRCodeReader isAvailable]) {
      txtView.placeholder = @"Visit https://bridges.torproject.org/ and Get Bridges. Tap the 'camera' icon above to scan the QR code, or manually copy-and-paste the \"bridge lines\" here:\n\ni.e.:\n172.0.0.1:1234 912ec803b2ce49e4a541068d495ab570912ec803\n172.0.0.2:4567 098f6bcd4621d373cade4e832627b4f6098f6bcd\n172.0.0.3:7890 a541068d495ab570912ec803a541068d495ab570\n\nPlease note that Onion Browser does not currently support bridges using Pluggable Transports (obfs3, scramblesuit, obfs4, etc.)\n\nIf you are in a location that uses more sophisticated methods to block Tor, you might have trouble getting a connection in Onion Browser until Pluggable Transports are supported.";
    } else {
      txtView.placeholder = @"Visit https://bridges.torproject.org/ and Get Bridges. Then copy-and-paste the \"bridge lines\" here:\n\ni.e.:\n172.0.0.1:1234 912ec803b2ce49e4a541068d495ab570912ec803\n172.0.0.2:4567 098f6bcd4621d373cade4e832627b4f6098f6bcd\n172.0.0.3:7890 a541068d495ab570912ec803a541068d495ab570\n\nPlease note that Onion Browser does not currently support bridges using Pluggable Transports (obfs3, scramblesuit, obfs4, etc.)\n\nIf you are in a location that uses more sophisticated methods to block Tor, you might have trouble getting a connection in Onion Browser until Pluggable Transports are supported.";
    }
    txtView.placeholderColor = [UIColor grayColor];
    txtView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
    txtView.tag = 50;
    [self.view addSubview: txtView];
}

- (NSString *)bridgesToBridgeLines {
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    NSManagedObjectContext *ctx = appDelegate.managedObjectContext;

    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Bridge" inManagedObjectContext:ctx];
    [request setEntity:entity];

    NSError *err = nil;
    NSArray *results = [ctx executeFetchRequest:request error:&err];
    if (results == nil) {
      NSLog(@"Data load did not complete successfully. Error: %@", [err localizedDescription]);
      return nil;
    } else if ([results count] < 1) {
      NSLog(@"Zero results");
      return nil;
    } else {
      NSLog(@"%lu results", (unsigned long)[results count]);
      NSMutableString *output = [[NSMutableString alloc] init];
      for (Bridge *bridge in results) {
        [output appendFormat:@"%@\n", bridge.conf];
      }
      return [NSString stringWithString:output];
    }
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
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"QRCode scanning is not supported by the current device" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];

    [alert show];
  }
}
#pragma mark - QRCodeReader Delegate Methods

- (void)reader:(QRCodeReaderViewController *)reader didScanResult:(NSString *)result {
    [self dismissViewControllerAnimated:YES completion:^{
        UIPlaceHolderTextView *txtView = (UIPlaceHolderTextView *)[self.view viewWithTag:50];
        txtView.text = result;
    }];
}

- (void)readerDidCancel:(QRCodeReaderViewController *)reader {
    [self dismissViewControllerAnimated:YES completion:NULL];
}




- (void)save {
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


  UIPlaceHolderTextView *txtView = (UIPlaceHolderTextView *)[self.view viewWithTag:50];
  NSString *txt = [txtView.text stringByReplacingOccurrencesOfString:@"[ ]+"
                                                       withString:@" "
                                                          options:NSRegularExpressionSearch
                                                            range:NSMakeRange(0, txtView.text.length)];
  for (NSString *line in [txt componentsSeparatedByString:@"\n"]) {
    NSString *newLine = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (![newLine isEqualToString:@""]) {
      Bridge *newBridge = [NSEntityDescription insertNewObjectForEntityForName:@"Bridge" inManagedObjectContext:ctx];
      [newBridge setConf:newLine];
      NSError *err = nil;
      if (![ctx save:&err]) {
        NSLog(@"Save did not complete successfully. Error: %@", [err localizedDescription]);
      }
    }
  }

  [self exitModal];
}
- (void)cancel {
  [self exitModal];
}



- (void)exitModal {
  AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
  NSManagedObjectContext *ctx = appDelegate.managedObjectContext;

  if (![appDelegate.tor didFirstConnect]) {
      UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Please Restart App"
                                                      message:@"Onion Browser will now close. Please start the app again to retry the Tor connection with the newly-configured bridges.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)"
                                                     delegate:self
                                            cancelButtonTitle:@"OK"
                                            otherButtonTitles:nil];
      [alert show];
  } else {
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
          UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Bridges"
                                                          message:[NSString stringWithFormat:@"%ld bridge%@ configured.You may need to quit the app and restart it to change the connection method.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)", (unsigned long)[newResults count], pluralize]
                                                         delegate:self
                                                cancelButtonTitle:@"Continue anyway"
                                                otherButtonTitles:@"Restart app", nil];
          [alert show];
      } else {
          UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Bridges Disabled"
                                                          message:@"No bridges are configured, so bridge connection mode is disabled. If you previously had bridges, you may need to quit the app and restart it to change the connection method.\n\n(If you restart and the app stays stuck at \"Connecting...\", please come back and double-check your bridge configuration or remove your bridges.)"
                                                         delegate:self
                                                cancelButtonTitle:@"Continue anyway"
                                                otherButtonTitles:@"Restart app", nil];
          [alert show];
      }
  }
}
- (void) alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([actionSheet.title isEqualToString:@"Please Restart App"]) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        [appDelegate wipeAppData];
        exit(0);
    } else {
        // One of the "Bridges Enabled" or "Bridges Disabled" prompts
        if (buttonIndex == 0) {
            [self dismissViewControllerAnimated:YES completion:nil];
        } else {
            AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
            [appDelegate wipeAppData];
            exit(0);
        }
    }
}




- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
