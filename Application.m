//
//  Application.m
//  Clutch
//
//  Created by NinjaLikesCheez on 15/08/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

#import "Application.h"
#import <UIKit/UIKit.h> // For UIDevice
//#import <dlfcn.h>
#include <objc/runtime.h> // For objc_getClass
//#import "LSApplicationProxy.h"
#import "out.h"

static NSString * const MobileInstallationPath = @"/private/var/mobile/Library/Caches/com.apple.mobile.installation.plist";

@implementation Application

- (NSString *)description
{
    return [NSString stringWithFormat:@"<Application: %p, Container: %@, BinaryPath: %@, DisplayName: %@, Name: %@, DirectoryPath: %@, RealUniqueID: %@, Version: %@, ShortVersion: %@, BundleID: %@, ExecutableName: %@, MinimumOSVersion: %@, Plugins: %@>", self, self.container, self.binaryPath, self.displayName, self.name, self.directoryPath, self.realUniqueID, self.version, self.shortVersion, self.bundleID, self.executableName, self.minimumOSVersion, self.plugins];
}

@end

#pragma mark - Plugin Object

@implementation Plugin

- (NSString *)description
{
    return [NSString stringWithFormat:@"<Plugin: %p, Path: %@, Executable: %@, Version: %@, Name:%@", self, self.path, self.executable, self.version, self.name];
}

@end

#pragma mark - Application Lister Implementation

@implementation ApplicationLister

+ (NSArray *)applications
{
    if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0)
    {
        return [self applicationListForiOS8];
    }
    else
    {
        return [self applicationListForiOS7];
    }
}

#pragma mark - Listing for iOS 8

+ (NSArray *)applicationListForiOS8
{
    Class LSApplicationWorkspace_class = objc_getClass("LSApplicationWorkspace");
    NSObject *workspaceObject = [LSApplicationWorkspace_class performSelector:@selector(defaultWorkspace)];
    NSArray *applicationslist = [workspaceObject performSelector:@selector(allInstalledApplications)];
    
    NSMutableArray *applicationList = [[NSMutableArray new] autorelease];
    
    for (id application in applicationslist)
    {
        NSString *applicationType = [application performSelector:@selector(applicationType)];
        
        if ([applicationType isEqualToString:@"User"])
        {
            NSString *resourceURL = [[[[application performSelector:@selector(resourcesDirectoryURL)] absoluteString] stringByRemovingPercentEncoding] stringByReplacingOccurrencesOfString:@"file://" withString:@""];
            
            NSString *container = [resourceURL stringByDeletingLastPathComponent];
            NSString *displayName = [application performSelector:@selector(itemName)];
            NSString *name = [application performSelector:@selector(itemName)];
            NSString *directoryPath = resourceURL;
            NSString *realUniqueID = [[resourceURL stringByDeletingLastPathComponent] lastPathComponent];
            NSString *version = [application performSelector:@selector(bundleVersion)];
            NSString *shortVersion = [application performSelector:@selector(shortVersionString)];
            NSString *bundleID = [application performSelector:@selector(applicationIdentifier)];
            NSString *minimumOSVersion = [application performSelector:@selector(minimumSystemVersion)];
            NSArray *plugins = [application performSelector:@selector(plugInKitPlugins)];
            
            NSString *executableName;
            NSString *binaryPath;
            
            // Find the Info.plist
            NSString *infoPlist = [resourceURL stringByAppendingString:@"/Info.plist"];
            NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPlist];
            
            executableName = info[@"CFBundleExecutable"];
            binaryPath = [resourceURL stringByAppendingFormat:@"/%@", executableName];
            
            NSMutableArray *pluginArray = [[[NSMutableArray alloc] init] autorelease];
            // Generate Plugin Objects
            for (id plugin in plugins)
            {
                // Grab AppEx Info.plist
                NSDictionary *pluginInfo = [plugin performSelector:@selector(infoPlist)];
                
                // Build information we need
                NSString *pluginPath = [[[[pluginInfo[@"CFBundleInfoPlistURL"] absoluteString] stringByRemovingPercentEncoding] stringByReplacingOccurrencesOfString:@"file://" withString:@""] stringByDeletingLastPathComponent];
                NSString *pluginExectuable = pluginInfo[@"CFBundleExecutable"];
                NSString *pluginVersion = pluginInfo[@"CFBundleShortVersionString"];
                NSString *pluginName = [plugin performSelector:@selector(localizedName)];
                
                Plugin *plugin = [[[Plugin alloc] init] autorelease];
                plugin.path = pluginPath;
                plugin.executable = pluginExectuable;
                plugin.version = pluginVersion;
                plugin.name = pluginName;
                
                [pluginArray addObject:plugin];
            }
                        
            Application *app = [[[Application alloc] init] autorelease];
            app.container = container;
            app.binaryPath = binaryPath;
            app.displayName = displayName;
            app.name = name;
            app.directoryPath = directoryPath;
            app.realUniqueID = realUniqueID;
            app.version = version;
            app.shortVersion = shortVersion;
            app.bundleID = bundleID;
            app.executableName = executableName;
            app.minimumOSVersion = minimumOSVersion;
            app.plugins = plugins;
            
            [applicationList addObject:app];
        }
        
    }
    
    return applicationList;
}

#pragma mark - Listing for iOS 7

+ (NSArray *)applicationListForiOS7
{
    NSDictionary *mobileInstallation = [NSDictionary dictionaryWithContentsOfFile:MobileInstallationPath];
    NSDictionary *applications = mobileInstallation[@"User"];
    
    NSMutableArray *applicationList = [NSMutableArray new];
    
    [applications enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        Application *app = [[[Application alloc] init] autorelease];
        
        NSString *scInfoPath = [NSString stringWithFormat:@"%@/SC_Info/", obj[@"Path"]];
        NSArray *scInfoPathFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:scInfoPath error:nil];
        
        /* Application isn't already cracked */
        if (scInfoPathFiles)
        {
            app.container = obj[@"Container"];
            
            if (obj[@"CFBundleDisplayName"])
            {
                app.displayName = obj[@"CFBundleDisplayName"];
            }
            else if (obj[@"CFBundleName"])
            {
                app.displayName = obj[@"CFBundleName"];
            }
            
            app.name = [[obj[@"Path"] lastPathComponent] stringByReplacingOccurrencesOfString:@".app" withString:@""];
            app.directoryPath = obj[@"Path"];
            app.realUniqueID = [app.container lastPathComponent];
            
            if (obj[@"CFBundleShortVersionString"])
            {
                app.version = obj[@"CFBundleShortVersionString"];
            }
            else
            {
                app.version = obj[@"CFBundleVersion"];
            }
            
            app.bundleID = key;
            app.executableName = obj[@"CFBundleExecutable"];
            app.minimumOSVersion = obj[@"MinimumOSVersion"];
            app.installed = YES;
            app.binaryPath = [NSString stringWithFormat:@"%@/%@", app.directoryPath, app.executableName];
            
            [applicationList addObject: app];
        }
        else
        {
            /* Application is already cracked */
            /* Ignore iiiiiit */
            
        }
    }];
    
    return applicationList;
}

@end

#pragma clang diagnostic pop