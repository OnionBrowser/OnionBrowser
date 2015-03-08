#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface RuleEditorController : UITableViewController <UISearchBarDelegate, UISearchDisplayDelegate, UITableViewDelegate>

@property AppDelegate *appDelegate;
@property NSMutableArray *sortedRuleNames;
@property NSMutableArray *inUseRuleNames;

@property UISearchBar *searchBar;
@property NSMutableArray *searchResult;

- (NSString *)ruleDisabledReason:(NSString *)rule;
- (void)disableRuleByName:(NSString *)rule withReason:(NSString *)reason;
- (void)enableRuleByName:(NSString *)rule;

@end
