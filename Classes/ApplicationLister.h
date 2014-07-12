//
//  ApplicationLister.h
//  Hand Brake
//
//  Created by Zorro
//
//  Re-tailored for use in Clutch

#import "Application.h"

@interface ApplicationLister : NSObject

+ (instancetype)sharedInstance;

- (NSArray *)installedApps;
- (NSArray *)crackedApps;
- (void)saveModifiedAppsCache;
- (NSArray *)modifiedApps;
-(void)crackedApp:(Application*) app;
@end