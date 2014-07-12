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

typedef NSDictionary* (*MobileInstallationLookup)(NSDictionary *options);

NSArray * get_application_list(BOOL sort) {
    
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
   
    if (mobileInstallationLookup)
        installedApps = mobileInstallationLookup(options); //convenient way
    else
    {
    	// iOS 8 workaround
    	NSMutableDictionary *iapps = [NSMutableDictionary new];
       	NSDictionary *userApps = [NSDictionary dictionaryWithContentsOfFile:mobileinstallationcache][@"User"];
       	
       	for (NSString *bID in userApps.allKeys)
       	{
       		NSDictionary *app = userApps[bID];
       		
       		NSMutableDictionary *tmp =  [NSMutableDictionary new];
       		
       		for (NSString *attribute in options[@"ReturnAttributes"])
       		{
       			if (app[attribute])
       			tmp[attribute] = app[attribute];
       		}
       		
       		iapps[bID] = tmp;
       	}
       	
       	installedApps = [iapps copy];
    }
    
    
    for (NSString *bundleID in [installedApps allKeys])
    {
        NSDictionary *appI=[installedApps objectForKey:bundleID];
        NSString *appPath=[[appI objectForKey:@"Path"]stringByAppendingString:@"/"];
        NSString *container=[[appPath stringByDeletingLastPathComponent]stringByAppendingString:@"/"];
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
                                                                   @"MinimumOSVersion":minimumOSVersion}];
            
            [returnArray addObject:app];
            
            [app release];
        }
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
