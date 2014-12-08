#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

#import "WebViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

@property (strong, atomic) WebViewController *curWebView;
@property (strong, atomic) NSHTTPCookieStorage *cookieStorage;
@property (strong, atomic) NSMutableDictionary *evHosts;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;
- (void)dumpCookies;

@end

