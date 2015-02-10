//
//  ApplicationsManager.h
//  Clutch
//
//  Created by Anton Titkov on 09.02.15.
//
//

#import <Foundation/Foundation.h>
#import "Application.h"

@interface ApplicationsManager : NSObject

+ (instancetype)sharedInstance;

- (NSArray *)installedApps;
- (NSArray *)crackedApps;
- (void)saveModifiedAppsCache;
- (NSArray *)modifiedApps;
- (void)crackedApp:(id)app;

@end