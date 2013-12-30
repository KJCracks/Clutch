#import "CAApplication.h"

@interface CAApplicationsController : NSObject

+ (instancetype)sharedInstance;

- (NSArray *)installedApps;
- (NSArray *)crackedApps;

@end