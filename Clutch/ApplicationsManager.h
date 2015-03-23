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

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDictionary *installedApps;

@end