#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

#import "WebViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (strong, atomic) WebViewController *webViewController;
@property (strong, atomic) NSHTTPCookieStorage *cookieStorage;

@property (readonly, strong, nonatomic) NSDictionary *searchEngines;

- (NSURL *)applicationDocumentsDirectory;
- (void)dumpCookies;
- (void)saveContext;

@end

