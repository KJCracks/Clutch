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
}

- (instancetype)initWithAppInfo:(NSDictionary *)info;

- (NSString *)applicationBaseDirectory;
- (NSString *)applicationDirectory;
- (NSString *)applicationDisplayName;
- (NSString *)applicationName;
- (NSString *)applicationBundleID;
- (NSString *)applicationBaseName;
- (NSString *)applicationExecutableName;
- (NSString *)realUniqueID;
- (NSString *)applicationVersion;
- (UIImage *)applicationIcon;
- (NSData *)applicationSINF;

- (void)crackWithDelegate:(id <CAApplicationDelegate>)delegate additionalLibs:(NSArray *)libs;

@end
