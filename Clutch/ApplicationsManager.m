//
//  ApplicationsManager.m
//  Clutch
//
//  Created by Anton Titkov on 09.02.15.
//
//

#define applistCachePath @"/etc/applist-cache.clutch"
#define crackedAppPath @"/etc/cracked.clutch"
#define mobileinstallationcache @"/private/var/mobile/Library/Caches/com.apple.mobile.installation.plist"
#define applicationPath @"/var/mobile/Containers/Bundle/Application/"

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
        _MIHandle = dlopen("/System/Library/PrivateFrameworks/MobileInstallation.framework/NearField", RTLD_NOW);
        
        _mobileInstallationLookup = NULL;
        
        if (_MIHandle)
            _mobileInstallationLookup = dlsym(_MIHandle,"MobileInstallationLookup");
        
    }
    return self;
}

- (NSArray *)_allApplications
{
    NSMutableArray *returnArray = [NSMutableArray new];
    
    NSDictionary* options = @{@"ApplicationType":@"User",
                              @"ReturnAttributes":@[@"CFBundleShortVersionString",
                                                    @"CFBundleVersion",
                                                    @"Path",
                                                    @"CFBundleDisplayName",
                                                    @"CFBundleExecutable",
                                                    @"MinimumOSVersion"]};
    
    if (_mobileInstallationLookup) {
        
        NSDictionary *installedApps;
        
        MobileInstallationLookup  mobileInstallationLookup = dlsym(dlopen(0,RTLD_LAZY),"MobileInstallationLookup");
        
        installedApps = mobileInstallationLookup(options);
        
        
        for (NSString *bundleID in [installedApps allKeys])
        {
            NSDictionary *appI=[installedApps objectForKey:bundleID];
            
            NSURL *bundleURL = [NSURL fileURLWithPath:[appI objectForKey:@"Path"]];
            
            NSString *scinfo=[bundleURL.path stringByAppendingPathComponent:@"SC_Info"];

            BOOL isDirectory;
            
            BOOL purchased = [[NSFileManager defaultManager]fileExistsAtPath:scinfo isDirectory:&isDirectory];
            
            if (purchased && isDirectory) {
                Application *app =[[Application alloc]initWithAppInfo:@{@"BundleContainer":bundleURL.URLByDeletingLastPathComponent,
                                                                        @"BundleURL":bundleURL}];
                
                [returnArray addObject:app];
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
                    Application *app =[[Application alloc]initWithAppInfo:@{@"BundleContainer":info.bundleContainerURL,
                                                                            @"BundleURL":info.bundleURL}];
                    
                    [returnArray addObject:app];
                }
            }
        }
        
        
    }
    
    return returnArray;
}

/*
- (NSArray *)modifiedApps {
    NSDictionary* cracked = [self crackedAppsList];
    NSArray* apps = [self _allApplications];
    NSMutableArray* modifiedApps = [[NSMutableArray alloc] init];
    for (Application* app in apps) {
        NSDictionary* appInfo = [cracked objectForKey:app.bundleIdentifier];
        if (appInfo == nil) {
            continue;
        }
        Application* oldApp = [[Application alloc] initWithAppInfo:appInfo];
        NSLog(@"new app version: %ld, %ld", (long)oldApp.appVersion, (long)app.appVersion);
        if (app.appVersion > oldApp.appVersion) {
            [modifiedApps addObject:app];
        }
    }
    NSLog(@"modified apps array %@", modifiedApps);
    return [modifiedApps copy];
}

-(void)crackedApp:(Application*) app {
    NSLog(@"cracked app ok");
    NSLog(@"this crack lol %ld", (long)app.appVersion);
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] initWithDictionary:[self crackedAppsList]];
    if (dict == nil) {
        dict = [[NSMutableDictionary alloc] init];
    }
    [dict setObject:app.dictionaryRepresentation forKey:app.applicationBundleID];
    //DEBUG(@"da dict %@", dict);
    [dict writeToFile:crackedAppPath atomically:YES];
}*/

-(NSDictionary*)crackedAppsList {
    return [NSDictionary dictionaryWithContentsOfFile:crackedAppPath];
}

-(void)saveModifiedAppsCache {
    //get_application_list(YES);
}

- (NSArray*) modifiedAppCache {
    //check mod. date;
    
    NSArray *cachedAppsInfo = [NSArray arrayWithContentsOfFile:applistCachePath];
    
    NSMutableArray *appsArray = [NSMutableArray new];
    
    for (NSDictionary *appInfo in cachedAppsInfo)
    {
        Application *app = [[Application alloc]initWithAppInfo:appInfo];
        [appsArray addObject:app];
    }
    
    return appsArray;
    
}
- (NSArray *)installedApps
{
    if ([NSFileManager.defaultManager fileExistsAtPath:applistCachePath])
    {
        //check mod. date;
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:applistCachePath error:nil];
        
        NSUInteger modifTime = (NSUInteger)[[attributes fileModificationDate] timeIntervalSince1970]; //mins yo
        NSUInteger currentTime = (NSUInteger)[[NSDate date] timeIntervalSince1970]/60; //mins yo
        
        if ((currentTime-modifTime) <= 5)
        {
            NSArray *cachedAppsInfo = [NSArray arrayWithContentsOfFile:applistCachePath];
            
            NSMutableArray *appsArray = [NSMutableArray new];
            
            for (NSDictionary *appInfo in cachedAppsInfo)
            {
                Application *app = [[Application alloc]initWithAppInfo:appInfo];
                [appsArray addObject:app];
            }
            
            return appsArray;
        }
    }
    
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
