//
//  ApplicationLister.h
//  Hand Brake
//
//  Created by Zorro
//
//  Re-tailored for use in Clutch

#import <dlfcn.h>
#import "ApplicationLister.h"
#import "out.h"
#import "Preferences.h"

#define applistCachePath @"/etc/applist-cache.clutch"
#define crackedAppPath @"/etc/cracked.clutch"
#define mobileinstallationcache @"/private/var/mobile/Library/Caches/com.apple.mobile.installation.plist"
#define applicationPath @"/var/mobile/Containers/Bundle/Application/"


typedef NSDictionary* (*MobileInstallationLookup)(NSDictionary *options);

NSMutableArray * get_ios_7_application_list()
{
    NSMutableArray *returnArray = [[[NSMutableArray alloc] init] autorelease];
    NSDictionary* options = @{@"ApplicationType":@"User",
                              @"ReturnAttributes":@[@"CFBundleShortVersionString",
                                                    @"CFBundleVersion",
                                                    @"Path",
                                                    @"CFBundleDisplayName",
                                                    @"CFBundleExecutable",
                                                    @"ApplicationSINF",
                                                    @"MinimumOSVersion"]};
    
    NSDictionary *installedApps;
    
    MobileInstallationLookup  mobileInstallationLookup = dlsym(dlopen(0,RTLD_LAZY),"MobileInstallationLookup");
    
    installedApps = mobileInstallationLookup(options);
    
    
    for (NSString *bundleID in [installedApps allKeys])
    {
        NSDictionary *appI=[installedApps objectForKey:bundleID];
        NSString *appPath=[[appI objectForKey:@"Path"]stringByAppendingString:@"/"];
        NSString *container=[[appPath stringByDeletingLastPathComponent] stringByAppendingString:@"/"];
        NSString *displayName=[appI objectForKey:@"CFBundleDisplayName"];
        NSString *executableName = [appI objectForKey:@"CFBundleExecutable"];
        
        NSString *minimumOSVersion = [appI objectForKey:@"MinimumOSVersion"];
        
        minimumOSVersion = minimumOSVersion!=nil ? minimumOSVersion : @"1.0";
        
        if (displayName == nil)
        {
            displayName=[[appPath lastPathComponent]stringByReplacingOccurrencesOfString:@".app" withString:@""];
        }
        
        NSString *version=@"";
        
        if ([[appI allKeys]containsObject:@"CFBundleShortVersionString"])
        {
            version=[appI objectForKey:@"CFBundleShortVersionString"];
        }
        else
        {
            version=[appI objectForKey:@"CFBundleVersion"];
        }
        
        NSData *SINF = appI[@"ApplicationSINF"];
        
        if (SINF)
        {
            Application *app =[[Application alloc]initWithAppInfo:@{@"ApplicationContainer":container,
                                                                    @"ApplicationDirectory":appPath,
                                                                    @"ApplicationDisplayName":displayName,
                                                                    @"ApplicationName":[[appPath lastPathComponent]stringByReplacingOccurrencesOfString:@".app" withString:@""],
                                                                    @"RealUniqueID":[container lastPathComponent],
                                                                    @"ApplicationBasename":[appPath lastPathComponent],
                                                                    @"ApplicationVersion":version,
                                                                    @"ApplicationBundleID":bundleID,
                                                                    //@"ApplicationSINF":SINF,
                                                                    @"ApplicationExecutableName":executableName,
                                                                    @"MinimumOSVersion":minimumOSVersion,
                                                                    @"PlugIn": @NO}];
            
            [returnArray addObject:app];
            
            [app release];
        }
    }
    
    return returnArray;
}

NSMutableArray * get_ios_8_application_list()
{
    DEBUG(@"iOS 8");
    
    NSMutableArray *returnArray = [[[NSMutableArray alloc] init] autorelease];
    NSError *error;
    NSArray *uuids = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:applicationPath error:&error];
    
    for (NSString *uuid in uuids)
    {
        // I'm using nested loops because this is a shit way of doing everything and 2.0 will lead to glory
        
        NSArray *uuidContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[applicationPath stringByAppendingString:uuid] error:&error];
        
        for (NSString *obj in uuidContents)
        {
            if ([obj.pathExtension isEqualToString:@"app"])
            {
                // In the .app
                NSString *appContentPath = [NSString stringWithFormat:@"%@%@/%@/", applicationPath, uuid, obj];
                
                NSArray *appContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:appContentPath error:&error];
                
                NSString *infoPlist = [appContentPath stringByAppendingString:@"Info.plist"]; // literally the worst thing since hitler
                NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPlist];
                
                NSString *version = info[@"CFBundleVersion"];
                if (!version)
                {
                    version = @"1.0";
                }
                
                NSString *shortVersion = info[@"CFBundleShortVersionString"];
                // Not used
                
                NSString *displayName = info[@"CFBundleDisplayName"];
                if (!displayName)
                {
                    displayName = [obj stringByDeletingPathExtension];
                }
                
                NSString *executable = info[@"CFBundleExecutable"];
                // If this isn't there, then son you got bigger problems
                
                NSString *minimumOSVersion = info[@"MinimumOSVersion"];
                if (!minimumOSVersion)
                {
                    minimumOSVersion = @"1.0";
                }
                
                NSString *bundleID = info[@"CFBundleIdentifier"];
                NSString *container = [NSString stringWithFormat:@"%@%@/", applicationPath, uuid];
                
                // Try to detect .appex bundles (App Extension)
                NSString *pluginPath = [appContentPath stringByAppendingString:@"PlugIns/"];
                
                BOOL extension = [[NSFileManager defaultManager] fileExistsAtPath:pluginPath];
                if (extension)
                {
                    NSArray *plugins = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginPath error:nil];
                    NSMutableArray *pluginList = [[[NSMutableArray alloc] init] autorelease];
                    
                    for (NSString *plugin in plugins)
                    {
                        NSString *extensionPath = [pluginPath stringByAppendingString:[NSString stringWithFormat:@"%@/", plugin]];
                    
                        NSString *extensionInfoPlistPath = [extensionPath stringByAppendingString:@"Info.plist"];
                        NSDictionary *extensionInfoPlist = [NSDictionary dictionaryWithContentsOfFile:extensionInfoPlistPath];
                    
                        NSString *extensionExecutableName = extensionInfoPlist[@"CFBundleExecutable"];
                        NSString *extensionName = extensionInfoPlist[@"CFBundleDisplayName"];
                        
                        if (extensionPath == nil)
                        {
                            NSLog(@"Extension path is nil wtf?");
                        }
                        
                        if (extensionExecutableName == nil)
                        {
                            NSLog(@"Extension executable name is nil wtf?");
                        }
                        
                        if (extensionName == nil)
                        {
                            NSLog(@"Extension name is nil wtf?");
                        }
                        
                        Plugin *plugin = [[[Plugin alloc] init] autorelease];
                        plugin.pluginPath = extensionPath;
                        plugin.pluginExecutableName = extensionExecutableName;
                        plugin.pluginName = extensionName;
                        
                        [pluginList addObject:plugin];
                    }
                    
                    Application *app =[[Application alloc]initWithAppInfo:@{
                                                                            @"ApplicationContainer":container,
                                                                            @"ApplicationDirectory":obj,
                                                                            @"ApplicationDisplayName":displayName,
                                                                            @"ApplicationName":[[obj lastPathComponent] stringByReplacingOccurrencesOfString:@".app" withString:@""],
                                                                            @"RealUniqueID":uuid,
                                                                            @"ApplicationBasename":obj,
                                                                            @"ApplicationVersion":version,
                                                                            @"ApplicationBundleID":bundleID,
                                                                            //@"ApplicationSINF":SINF,
                                                                            @"ApplicationExecutableName":executable,
                                                                            @"MinimumOSVersion":minimumOSVersion,
                                                                            @"PlugIn": @YES,
                                                                            @"PlugIns" : pluginList
                                                                            }];
                    [returnArray addObject:app];
                    [app release];
                }
                else
                {
                        Application *app =[[Application alloc]initWithAppInfo:@{
                                 @"ApplicationContainer":container,
                                 @"ApplicationDirectory":obj,
                                 @"ApplicationDisplayName":displayName,
                                 @"ApplicationName":[[obj lastPathComponent] stringByReplacingOccurrencesOfString:@".app" withString:@""],
                                 @"RealUniqueID":uuid,
                                 @"ApplicationBasename":obj,
                                 @"ApplicationVersion":version,
                                 @"ApplicationBundleID":bundleID,
                                 //@"ApplicationSINF":SINF,
                                 @"ApplicationExecutableName":executable,
                                 @"MinimumOSVersion":minimumOSVersion,
                                 @"PlugIn": @NO
                                 }];
                    
                    [returnArray addObject:app];
                    [app release];
                }
                
                break;
            }
        }
    }
    
    return returnArray;
}

NSArray * get_application_list(BOOL sort) {
    
    NSMutableArray *returnArray = [[[NSMutableArray alloc] init] autorelease];
    if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0)
    {
        returnArray = get_ios_8_application_list();
    }
    else
    {
        returnArray = get_ios_7_application_list();
    }
    
	if ([returnArray count] == 0)
    {
		return nil;
	}
    
    if (sort)
    {
        NSSortDescriptor *sorter = [[NSSortDescriptor alloc]
                                    initWithKey:@"applicationName"
                                    ascending:YES
                                    selector:@selector(localizedCaseInsensitiveCompare:)];
        
        NSArray *sortDescriptors = [NSArray arrayWithObject: sorter];
        
        [returnArray sortUsingDescriptors:sortDescriptors];
    }
    
    //caching is good
    NSMutableArray *cacheArray = [NSMutableArray new];
    
    for (Application *app in returnArray)
    {
        [cacheArray addObject:[app dictionaryRepresentation]];
    }
    
    if (cacheArray.count > 0)
    {
        [cacheArray writeToFile:applistCachePath atomically:YES];
        
    }
    
    [cacheArray release];
    
	return (NSArray *) returnArray;
}

@implementation ApplicationLister

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static ApplicationLister *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [ApplicationLister new];
    });
    
    return shared;
}

- (NSArray *)modifiedApps {
    NSDictionary* cracked = [self crackedAppsList];
    NSArray* apps = get_application_list(YES);
    NSMutableArray* modifiedApps = [[NSMutableArray alloc] init];
    for (Application* app in apps) {
        NSDictionary* appInfo = [cracked objectForKey:app.applicationBundleID];
        if (appInfo == nil) {
            continue;
        }
        Application* oldApp = [[Application alloc] initWithAppInfo:appInfo];
        DEBUG(@"new app version: %ld, %ld", (long)oldApp.appVersion, (long)app.appVersion);
        if (app.appVersion > oldApp.appVersion) {
            [modifiedApps addObject:app];
        }
        [oldApp release];
    }
    DEBUG(@"modified apps array %@", modifiedApps);
    return [modifiedApps autorelease];
}

-(void)crackedApp:(Application*) app {
    DEBUG(@"cracked app ok");
    DEBUG(@"this crack lol %ld", (long)app.appVersion);
    NSMutableDictionary* dict = [[NSMutableDictionary alloc] initWithDictionary:[self crackedAppsList]];
    if (dict == nil) {
        dict = [[NSMutableDictionary alloc] init];
    }
    [dict setObject:app.dictionaryRepresentation forKey:app.applicationBundleID];
    //DEBUG(@"da dict %@", dict);
    [dict writeToFile:crackedAppPath atomically:YES];
    
    [dict release];
}

-(NSDictionary*)crackedAppsList {
    return [[[NSDictionary alloc] initWithContentsOfFile:crackedAppPath] autorelease];
}

-(void)saveModifiedAppsCache {
    get_application_list(YES);
}

- (NSArray*) modifiedAppCache {
    //check mod. date;
    
    NSArray *cachedAppsInfo = [NSArray arrayWithContentsOfFile:applistCachePath];
    
    NSMutableArray *appsArray = [[NSMutableArray new] autorelease];
    
    for (NSDictionary *appInfo in cachedAppsInfo)
    {
        Application *app = [[Application alloc]initWithAppInfo:appInfo];
        [appsArray addObject:app];
        [app release];
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
        
        if ((currentTime-modifTime) > 5)
        {
            return get_application_list(YES);
        }

        NSArray *cachedAppsInfo = [NSArray arrayWithContentsOfFile:applistCachePath];
        
        NSMutableArray *appsArray = [[NSMutableArray new] autorelease];
        
        for (NSDictionary *appInfo in cachedAppsInfo)
        {
            Application *app = [[Application alloc]initWithAppInfo:appInfo];
            [appsArray addObject:app];
            [app release];
        }
        
        return appsArray;
    }
    
    return get_application_list(YES);
}

- (NSArray *)crackedApps
{
    NSString *crackedPath = [NSString stringWithFormat:@"%@/", [[Preferences sharedInstance] ipaDirectory]];
    NSArray *array=[[NSArray alloc]initWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:crackedPath error:nil]];
    NSMutableArray *paths=[[[NSMutableArray alloc] init] autorelease];
    
    for (int i=0; i<array.count; i++)
    {
        if (![[array[i] pathExtension] caseInsensitiveCompare:@"ipa"])
        {
            [paths addObject:array[i]];
        }
    }
    
    [array release];
    
    return paths;
}

@end
