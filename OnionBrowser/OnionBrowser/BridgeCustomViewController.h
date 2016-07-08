#import <UIKit/UIKit.h>
#import "QRCodeReaderViewController.h"

@interface BridgeCustomViewController : UIViewController <QRCodeReaderDelegate>

- (void)qrscan;
- (void)save;
- (void)cancel;

- (void)exitModal;

@end
