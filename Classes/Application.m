//
//  Application.m
//  Hand Brake
//
//  Created by Ninja on 28/02/2013.
//  Copyright (c) 2013 Hackulous. All rights reserved.
//

#import "Application.h"
#import "Binary.h"

@interface Plugin ()
{
    
}

@end

@implementation Plugin

@end

@interface Application ()
{
    
    NSString *applicationContainer,    // /private/var/mobile/Applications/$UUID/ OR /private/var/mobile/Container/Application/$UUID
    *applicationDisplayName,           // what you see on SpringBoard
    *applicationName,                  // SuperMonkeyBall.app - .app = SuperMonkeyBall
    *appDirectory,                     // SuperMoneyBall.app
    *realUniqueID,                     // C320A08E-1295-4F40-8B4F-9D8A5634CE92
    *applicationVersion,               // 1.0
    *applicationBundleID,              // com.apple.purpleshit
    *applicationExecutableName,        // Clutch-1.4.7
    *minimumOSVersion;                 // 4.3
    
    BOOL hasPlugin;
    
    NSArray *plugins;                  // Array of Plugins
    
    NSData *applicationSINF;           // NSData of /SC_Info/$(applicationExecutableName).sinf
    UIImage *applicationIcon;          // 

    NSDictionary *dictRep;             // NSDictionary representation of all stuff above,except applicationIcon(UIImage)
}

@end

@implementation Application

- (id)initWithAppInfo:(NSDictionary *)info
{
    
    if (self = [super init]) {
        // Application
        applicationContainer = info[@"ApplicationContainer"];
        applicationDisplayName = info[@"ApplicationDisplayName"];
        applicationName = info[@"ApplicationName"];
        appDirectory = info[@"ApplicationBasename"];
        realUniqueID = info[@"RealUniqueID"];
        applicationVersion = info[@"ApplicationVersion"];
        applicationBundleID = info[@"ApplicationBundleID"];
        applicationExecutableName = info[@"ApplicationExecutableName"];
        applicationSINF = info[@"ApplicationSINF"];
        minimumOSVersion = info[@"MinimumOSVersion"];
        
        // Extension
        if ([info[@"PlugIn"]  isEqual: @YES])
        {
            hasPlugin = YES;
            
            plugins = info[@"PlugIns"];
        }
        else
        {
            hasPlugin = NO;
        }

        NSMutableDictionary* copy = [[NSMutableDictionary alloc] initWithDictionary:info];
        [copy removeObjectForKey:@"ApplicationSINF"]; //slow
        dictRep = copy;
        isCracking = NO;
        _info = info;
        
    }
    return self;
}

- (NSString *)applicationContainer
{
    return applicationContainer;
}

- (NSString*) applicationDirectory {
    return [applicationContainer lastPathComponent];
}

- (NSString *)applicationDisplayName
{
    return applicationDisplayName;
}

- (NSString *)applicationName
{
    return applicationName;
}

- (NSString *)appDirectory
{
    return appDirectory;
}

- (NSString *)realUniqueID
{
    return realUniqueID;
}

- (UIImage *)applicationIcon
{
    return applicationIcon;
}

- (NSString *)applicationVersion
{
    return applicationVersion;
}
- (NSString *)applicationExecutableName
{
    return applicationExecutableName;
}
- (NSString *)applicationBundleID
{
    return applicationBundleID;
}

- (NSData *)applicationSINF
{
    return applicationSINF;
}

- (NSString *)minimumOSVersion
{
    return minimumOSVersion;
}

- (NSArray *)plugins
{
    return plugins;
}

- (BOOL)hasPlugin
{
    return hasPlugin;
}

- (NSDictionary *)dictionaryRepresentation
{
    return dictRep;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, appName: %@, bundleID: %@>",NSStringFromClass([self class]),self,self.applicationName,self.applicationBundleID];
}

-(NSInteger)appVersion {
    return [[applicationVersion stringByReplacingOccurrencesOfString:@"." withString:@""] integerValue];
}

@end
