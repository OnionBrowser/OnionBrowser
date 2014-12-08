#import <Foundation/Foundation.h>

@interface HTTPSEverywhereRule : NSObject

@property NSString *name;
@property NSArray *exclusions;
@property NSDictionary *rules;
@property NSDictionary *securecookies;
@property NSString *platform;
@property BOOL on_by_default;
@property NSString *notes;
/* not loaded here since HTTPSEverywhere class has a big list of them */
@property NSArray *targets;

- (id)initWithDictionary:(NSDictionary *)dict;
- (NSURL *)apply:(NSURL *)url;

@end
