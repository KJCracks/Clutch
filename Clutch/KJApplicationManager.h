//
//  ApplicationsManager.h
//  Clutch
//
//  Created by Anton Titkov on 09.02.15.
//
//

#import "Application.h"
#import <Foundation/Foundation.h>

@interface KJApplicationManager : NSObject

- (instancetype)init;

@property (nonatomic, readonly, copy) NSDictionary *installedApps;

- (NSDictionary *)cachedApplications;

@end
