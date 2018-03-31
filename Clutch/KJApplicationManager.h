//
//  ApplicationsManager.h
//  Clutch
//
//  Created by Anton Titkov on 09.02.15.
//
//

#import "Application.h"

NS_ASSUME_NONNULL_BEGIN

@interface KJApplicationManager : NSObject

- (instancetype)init;

@property (nonatomic, readonly, copy) NSDictionary *installedApps;
@property (nonatomic, readonly, copy) NSDictionary *cachedApplications;

@end

NS_ASSUME_NONNULL_END
