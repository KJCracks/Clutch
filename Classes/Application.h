//
//  Application.h
//  Hand Brake
//
//  Created by Ninja on 28/02/2013.
//  Copyright (c) 2013 Hackulous. All rights reserved.
//
//  Improved by Zorro :P
//
//  Re-tailored for use in Clutch

#import <Foundation/Foundation.h>
#include <UIKit/UIKit.h>

@class Application;
@protocol ApplicationDelegate <NSObject>

- (void)crackingProcessStarted:(Application*)app;
- (void)application:(Application *)app crackingProcessStatusChanged:(NSString *)status progress:(float)progress;
- (void)crackingProcessFinished:(Application *)app;

@end

@interface Application : NSObject
{
@public
    BOOL isCracking;
    NSDictionary *progress;
    NSDictionary* _info;
}

- (instancetype)initWithAppInfo:(NSDictionary *)info;

- (NSString *)appDirectory;
- (NSString *)applicationContainer;
- (NSString*) applicationDirectory;
- (NSString *)applicationBundleID;
- (NSString *)applicationDisplayName;
- (NSString *)applicationExecutableName;
- (NSString *)applicationName;
- (NSString *)realUniqueID;
- (NSString *)applicationVersion;
- (NSString *)minimumOSVersion;
- (UIImage *)applicationIcon;
- (NSData *)applicationSINF;
- (NSInteger)appVersion;

- (NSDictionary *)dictionaryRepresentation;

@end
