#import "CAApplication.h"
#import "MobileInstallation.h"

@interface CAApplicationsController : NSObject

+ (instancetype)sharedInstance;

- (NSArray *)installedApps;
- (NSArray *)crackedApps;

@end