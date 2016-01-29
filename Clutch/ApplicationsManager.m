//
//  ApplicationsManager.m
//  Clutch
//
//  Created by Anton Titkov on 09.02.15.
//
//

#define applistCachePath @"applist-cache.plist"
#define dumpedAppPath @"/etc/dumped.clutch"

#import <dlfcn.h>
#import "ApplicationsManager.h"
#import "FBApplicationInfo.h"
#import "LSApplicationProxy.h"
#import "LSApplicationWorkspace.h"

typedef NSDictionary* (*MobileInstallationLookup)(NSDictionary *options);

@interface ApplicationsManager ()
{
    void * _MIHandle;
    MobileInstallationLookup _mobileInstallationLookup;
    NSMutableArray* _cachedApps;
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
    if ([[NSFileManager defaultManager] fileExistsAtPath:applistCachePath]) {
        _cachedApps = [[NSMutableArray alloc] initWithContentsOfFile:applistCachePath];
    }
    else {
        _cachedApps = [NSMutableArray new];
    }
    return self;
}

- (NSDictionary *)_allApplications
{
    _cachedApps = [NSMutableArray new];
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
                NSString* name = appI[@"CFBundleDisplayName"];
                if (name == nil) {
                    name = appI[@"CFBundleExecutable"];
                }
                NSDictionary* bundleInfo = @{@"BundleContainer":bundleURL.URLByDeletingLastPathComponent,
                                             @"BundleURL":bundleURL,
                                             @"DisplayName": name,
                                             @"BundleIdentifier": bundleID};
                Application *app =[[Application alloc]initWithBundleInfo:bundleInfo];
                [self cacheBundle:bundleInfo];
                returnValue[bundleID] = app;
            }
        }
        
    }else
    {
        LSApplicationWorkspace* applicationWorkspace = [LSApplicationWorkspace defaultWorkspace];
        
        NSArray *proxies = [applicationWorkspace allApplications];
        NSDictionary *bundleInfo = nil;
        
        for (FBApplicationInfo * proxy in proxies) {
            
            NSString *appType = [proxy performSelector:@selector(applicationType)];
            
            if ([appType isEqualToString:@"User"] && proxy.bundleContainerURL && proxy.bundleURL) {
                
                NSString *scinfo=[proxy.bundleURL.path stringByAppendingPathComponent:@"SC_Info"];
                
                BOOL isDirectory;
                
                BOOL purchased = [[NSFileManager defaultManager]fileExistsAtPath:scinfo isDirectory:&isDirectory];
                
                if (purchased && isDirectory) {
                    NSString *itemName = ((LSApplicationProxy*) proxy).itemName;
                    
                    if (!itemName)
                        itemName = ((LSApplicationProxy*)proxy).localizedName;
                    
                    bundleInfo = @{
                                   @"BundleContainer":proxy.bundleContainerURL,
                                   @"BundleURL":proxy.bundleURL,
                                   @"DisplayName": itemName,
                                   @"BundleIdentifier": proxy.bundleIdentifier
                                   };
                    
                    Application *app =[[Application alloc]initWithBundleInfo:bundleInfo];
                    returnValue[proxy.bundleIdentifier] = app;
                    [self cacheBundle:bundleInfo];
                    
                }
            }
        }
        
    }
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(queue, ^{
        [_cachedApps writeToFile:applistCachePath atomically:YES];
    });
    
    return [returnValue copy];
}

- (NSDictionary *)installedApps
{
    return [self _allApplications];
}

-(NSDictionary*)_allCachedApplications {
    if ([_cachedApps count] < 1) {
        return [self _allApplications];
    }
    NSMutableDictionary* returnValue = [NSMutableDictionary new];
    for (NSDictionary* bundleInfo in _cachedApps) {
        Application *app =[[Application alloc]initWithBundleInfo:bundleInfo];
        returnValue[bundleInfo[@"BundleIdentifier"]] = app;
    }
    return returnValue;
}

-(void)cacheBundle:(NSDictionary*) bundle {
    [_cachedApps addObject:bundle];
}


- (NSArray *)dumpedApps
{
    NSString *dumpedPath = @""; //[NSString stringWithFormat:@"%@/", [[Preferences sharedInstance] ipaDirectory]];
    NSArray *array=[[NSArray alloc]initWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dumpedPath error:nil]];
    
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