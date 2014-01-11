//
//  Application.h
//  Hand Brake
//
//  Created by Ninja on 28/02/2013.
//  Copyright (c) 2013 Hackulous. All rights reserved.
//
//  Improved by Zorro :P
//

#import <Foundation/Foundation.h>
#include <UIKit/UIKit.h>

@class CAApplication;
@protocol CAApplicationDelegate <NSObject>

- (void)crackingProcessStarted:(CAApplication*)app;
- (void)application:(CAApplication *)app crackingProcessStatusChanged:(NSString *)status progress:(float)progress;
- (void)crackingProcessFinished:(CAApplication *)app;

@end

@interface CAApplication : NSObject
{
@public
    BOOL isCracking;
    NSDictionary *progress;
    NSDictionary* _info;
}

- (instancetype)initWithAppInfo:(NSDictionary *)info;

- (NSString *)appDirectory;
- (NSString *)applicationContainer;
- (NSString *)applicationBundleID;
- (NSString *)applicationDisplayName;
- (NSString *)applicationExecutableName;
- (NSString *)applicationName;
- (NSString *)realUniqueID;
- (NSString *)applicationVersion;
- (NSString *)minimumOSVersion;
- (UIImage *)applicationIcon;
- (NSData *)applicationSINF;

- (NSDictionary *)dictionaryRepresentation;

- (void)crackWithDelegate:(id <CAApplicationDelegate>)delegate additionalLibs:(NSArray *)libs;

@end
