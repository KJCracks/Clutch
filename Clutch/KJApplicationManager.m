//
//  ApplicationsManager.m
//  Clutch
//
//  Created by Anton Titkov on 09.02.15.
//
//

#define applistCachePath @"applist-cache.plist"
#define dumpedAppPath @"/etc/dumped.clutch"

#import "KJApplicationManager.h"
#import "FBApplicationInfo.h"
#import "LSApplicationProxy.h"
#import "LSApplicationWorkspace.h"
#import <dlfcn.h>

typedef NSDictionary *(*MobileInstallationLookup)(NSDictionary *options);

@interface KJApplicationManager ()
@property (nonatomic, retain) NSMutableArray *cachedApps;
@end

@implementation KJApplicationManager

- (instancetype)init {
    if ((self = [super init])) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:applistCachePath]) {
            _cachedApps = [[NSMutableArray alloc] initWithContentsOfFile:applistCachePath];
        } else {
            _cachedApps = [NSMutableArray new];
        }
    }

    return self;
}

- (NSDictionary *)listApplicationsForiOS7AndLower {
    MobileInstallationLookup mobileInstallationLookup;
    void *MIHandle;

    NSMutableDictionary *returnValue = [NSMutableDictionary new];
    MIHandle = dlopen("/System/Library/PrivateFrameworks/MobileInstallation.framework/MobileInstallation", RTLD_NOW);
    mobileInstallationLookup = NULL;

    if (MIHandle) {
        mobileInstallationLookup = (MobileInstallationLookup)dlsym(MIHandle, "MobileInstallationLookup");
        if (mobileInstallationLookup) {

            NSDictionary *installedApps;
            NSDictionary *options = @{
                @"ApplicationType" : @"User",
                @"ReturnAttributes" : @[
                    @"CFBundleShortVersionString",
                    @"CFBundleVersion",
                    @"Path",
                    @"CFBundleDisplayName",
                    @"CFBundleExecutable",
                    @"MinimumOSVersion"
                ]
            };

            installedApps = mobileInstallationLookup(options);

            for (NSString *bundleID in installedApps.allKeys) {
                NSDictionary *appI = installedApps[bundleID];
                NSURL *bundleURL = [NSURL fileURLWithPath:appI[@"Path"]];
                NSString *scinfo = [bundleURL.path stringByAppendingPathComponent:@"SC_Info"];

                BOOL isDirectory;
                BOOL purchased = [[NSFileManager defaultManager] fileExistsAtPath:scinfo isDirectory:&isDirectory];

                if (purchased && isDirectory) {
                    NSString *name = appI[@"CFBundleDisplayName"];
                    if (name == nil) {
                        name = appI[@"CFBundleExecutable"];
                    }

                    NSDictionary *bundleInfo = @{
                        @"BundleContainer" : bundleURL.URLByDeletingLastPathComponent,
                        @"BundleURL" : bundleURL,
                        @"DisplayName" : name,
                        @"BundleIdentifier" : bundleID
                    };
                    Application *app = [[Application alloc] initWithBundleInfo:bundleInfo];
                    returnValue[bundleID] = app;

                    [self cacheBundle:bundleInfo];
                }
            }
        }
    }

    [self writeToCache];

    return returnValue;
}

- (NSDictionary *)listApplicationsForiOS8AndHigher {
    NSMutableDictionary *returnValue = [NSMutableDictionary new];
    LSApplicationWorkspace *applicationWorkspace = [LSApplicationWorkspace defaultWorkspace];

    NSArray *proxies = [applicationWorkspace allApplications];
    NSDictionary *bundleInfo = nil;

    for (FBApplicationInfo *proxy in proxies) {
        NSString *appType = [proxy performSelector:@selector(applicationType)];

        if ([appType isEqualToString:@"User"] && proxy.bundleContainerURL && proxy.bundleURL) {
            NSString *scinfo = [proxy.bundleURL.path stringByAppendingPathComponent:@"SC_Info"];

            BOOL isDirectory;
            BOOL purchased = [[NSFileManager defaultManager] fileExistsAtPath:scinfo isDirectory:&isDirectory];

            if (purchased && isDirectory) {
                NSString *itemName = ((LSApplicationProxy *)proxy).itemName;

                if (!itemName) {
                    itemName = ((LSApplicationProxy *)proxy).localizedName;
                }

                bundleInfo = @{
                    @"BundleContainer" : proxy.bundleContainerURL,
                    @"BundleURL" : proxy.bundleURL,
                    @"DisplayName" : itemName,
                    @"BundleIdentifier" : proxy.bundleIdentifier
                };

                Application *app = [[Application alloc] initWithBundleInfo:bundleInfo];
                returnValue[proxy.bundleIdentifier] = app;

                [self cacheBundle:bundleInfo];
            }
        }
    }

    [self writeToCache];

    return returnValue.copy;
}

- (void)writeToCache {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    dispatch_async(queue, ^{
        [self.cachedApps writeToFile:applistCachePath atomically:YES];
    });
}

- (NSDictionary *)_allApplications {
    NSDictionary *returnValue;
    if (SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(NSFoundationVersionNumber_iOS_7_0)) {
        returnValue = [self listApplicationsForiOS7AndLower];
    } else {
        returnValue = [self listApplicationsForiOS8AndHigher];
    }

    return returnValue.copy;
}

- (NSDictionary *)installedApps {
    return [self _allApplications];
}

- (NSDictionary *)cachedApplications {
    if (_cachedApps.count < 1) {
        return [self _allApplications];
    }

    NSMutableDictionary *returnValue = [NSMutableDictionary new];
    for (NSDictionary *bundleInfo in _cachedApps) {
        Application *app = [[Application alloc] initWithBundleInfo:bundleInfo];
        returnValue[bundleInfo[@"BundleIdentifier"]] = app;
    }

    return returnValue;
}

- (void)cacheBundle:(NSDictionary *)bundle {
    [_cachedApps addObject:bundle];
}

- (NSArray *)dumpedApps {
    NSString *dumpedPath = @"";
    NSArray *array =
        [[NSArray alloc] initWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dumpedPath error:nil]];

    NSMutableArray *paths = [NSMutableArray new];

    for (NSUInteger i = 0; i < array.count; i++) {
        if (![[array[i] pathExtension] caseInsensitiveCompare:@"ipa"]) {
            [paths addObject:array[i]];
        }
    }

    return paths;
}

@end
