//
//  Application.m
//  Clutch
//
//  Created by NinjaLikesCheez on 15/08/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#import "Application.h"

static NSString * const MobileInstallationPath = @"/private/var/mobile/Library/Caches/com.apple.mobile.installation.plist";

@implementation Application

- (NSString *)description
{
    return [NSString stringWithFormat:@"<Application: %p, DisplayName: %@, Name: %@, BundleID: %@, DirectoryPath: %@, ExectuableName: %@, Installed: %s", self, self.displayName, self.name, self.bundleID, self.directoryPath, self.executableName, self.installed ? "YES" : "NO"];
}

@end

@implementation ApplicationLister

+ (NSArray *)applications
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
            NSArray *sinfArray = [scInfoPathFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension='sinf'"]];
            NSArray *suppArray = [scInfoPathFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension='supp'"]];
            NSArray *supfArray = [scInfoPathFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension='supf'"]];
            
            if (sinfArray.count != 0)
            {
                app.sinf = sinfArray[0];
            }
            
            if (suppArray.count != 0)
            {
                app.supp = suppArray[0];
            }
            
            if (supfArray.count != 0)
            {
                app.supf = supfArray[0];
            }
            
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