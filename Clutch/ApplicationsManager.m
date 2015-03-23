//
//  ApplicationsManager.m
//  Clutch
//
//  Created by Anton Titkov on 09.02.15.
//
//

#define applistCachePath @"/etc/applist-cache.clutch"
#define crackedAppPath @"/etc/cracked.clutch"

#import <dlfcn.h>
#import "ApplicationsManager.h"
#import "FBApplicationInfo.h"

typedef NSDictionary* (*MobileInstallationLookup)(NSDictionary *options);

@interface ApplicationsManager ()
{
    void * _MIHandle;
    MobileInstallationLookup _mobileInstallationLookup;
}
@end

@implementation ApplicationsManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static id shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [self new];
    });
    
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _MIHandle = dlopen("/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation", RTLD_NOW);
        
        _mobileInstallationLookup = NULL;
        
        if (_MIHandle)
            _mobileInstallationLookup = dlsym(_MIHandle,"MobileInstallationLookup");
        
    }
    return self;
}

- (NSDictionary *)_allApplications
{
    NSMutableDictionary *returnValue = [NSMutableDictionary new];
    
    NSDictionary* options = @{@"ApplicationType":@"User",
                              @"ReturnAttributes":@[@"CFBundleShortVersionString",
                                                    @"CFBundleVersion",
                                                    @"Path",
                                                    @"CFBundleDisplayName",
                                                    @"CFBundleExecutable",
                                                    @"MinimumOSVersion"]};
    
    if (_mobileInstallationLookup) {
        
        NSDictionary *installedApps;
        
        installedApps = _mobileInstallationLookup(options);
        
        
        for (NSString *bundleID in [installedApps allKeys])
        {
            NSDictionary *appI=installedApps[bundleID];
            
            NSURL *bundleURL = [NSURL fileURLWithPath:appI[@"Path"]];
            
            NSString *scinfo=[bundleURL.path stringByAppendingPathComponent:@"SC_Info"];

            BOOL isDirectory;
            
            BOOL purchased = [[NSFileManager defaultManager]fileExistsAtPath:scinfo isDirectory:&isDirectory];
            
            if (purchased && isDirectory) {
                Application *app =[[Application alloc]initWithBundleInfo:@{@"BundleContainer":bundleURL.URLByDeletingLastPathComponent,
                                                                           @"BundleURL":bundleURL}];
                
                returnValue[bundleID] = app;
            }
        }
        
    }else
    {
        id applicationWorkspace = [NSClassFromString(@"LSApplicationWorkspace") performSelector:@selector(defaultWorkspace)];
        
        NSArray *proxies = [applicationWorkspace performSelector:@selector(allApplications)];
        
        NSMutableArray *_iApps = [NSMutableArray new];
        
        for (id proxy in proxies) {
            FBApplicationInfo *appInfo = [[FBApplicationInfo alloc]initWithApplicationProxy:proxy];
            
            if (appInfo) {
                [_iApps addObject:appInfo];
            }
        }
        
        for (FBApplicationInfo *info in _iApps) {
            
            if ([options[@"ApplicationType"] isEqualToString:@"User"]&&([info.bundleContainerURL.path hasPrefix:@"/private"]||[info.bundleContainerURL.path hasPrefix:@"/var"]))
            {
                NSString *scinfo=[info.bundleURL.path stringByAppendingPathComponent:@"SC_Info"];
                
                BOOL isDirectory;
                
                BOOL purchased = [[NSFileManager defaultManager]fileExistsAtPath:scinfo isDirectory:&isDirectory];
                
                if (purchased && isDirectory) {
                    Application *app =[[Application alloc]initWithBundleInfo:@{@"BundleContainer":info.bundleContainerURL,
                                                                               @"BundleURL":info.bundleURL}];
                    
                    returnValue[info.bundleIdentifier] = app;
                }
            }
        }
        
        
    }
    
    return [returnValue copy];
}

- (NSDictionary *)installedApps
{
    return [self _allApplications];
}

- (NSArray *)crackedApps
{
    NSString *crackedPath = @""; //[NSString stringWithFormat:@"%@/", [[Preferences sharedInstance] ipaDirectory]];
    NSArray *array=[[NSArray alloc]initWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:crackedPath error:nil]];
    
    NSMutableArray *paths=[NSMutableArray new];
    
    for (int i=0; i<array.count; i++)
    {
        if (![[array[i] pathExtension] caseInsensitiveCompare:@"ipa"])
        {
            [paths addObject:array[i]];
        }
    }
    
    return paths;
}


@end
