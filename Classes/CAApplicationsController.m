#import "CAApplicationsController.h"
#import "MobileInstallation.h"
#import "out.h"
#import "Prefs.h"

#define applistCachePath @"/etc/applist-cache.clutch"

NSArray * get_application_list(BOOL sort) {
    
    NSMutableArray *returnArray = [NSMutableArray new];
    
    NSDictionary* options = @{@"ApplicationType":@"User",@"ReturnAttributes":@[@"CFBundleShortVersionString",@"CFBundleVersion",@"Path",@"CFBundleDisplayName",@"CFBundleExecutable",@"ApplicationSINF",@"MinimumOSVersion"]};
    
    NSDictionary *installedApps = MobileInstallationLookup(options);
    
    //DebugLog(@"installed apps %@", installedApps);
    
    for (NSString *bundleID in [installedApps allKeys]) {
        
        NSDictionary *appI=[installedApps objectForKey:bundleID];
        NSString *appPath=[[appI objectForKey:@"Path"]stringByAppendingString:@"/"];
        NSString *container=[[appPath stringByDeletingLastPathComponent]stringByAppendingString:@"/"];
        NSString *displayName=[appI objectForKey:@"CFBundleDisplayName"];
        NSString *executableName = [appI objectForKey:@"CFBundleExecutable"];
        
        NSString *minimumOSVersion = [appI objectForKey:@"MinimumOSVersion"];

        minimumOSVersion = minimumOSVersion!=nil ? minimumOSVersion : @"1.0";
        
        if (displayName==nil) {
            displayName=[[appPath lastPathComponent]stringByReplacingOccurrencesOfString:@".app" withString:@""];
        }
        
        NSString *version=@"";
        
        if ([[appI allKeys]containsObject:@"CFBundleShortVersionString"]) {
            version=[appI objectForKey:@"CFBundleShortVersionString"];
        }else{
            version=[appI objectForKey:@"CFBundleVersion"];
        }
        
        NSData *SINF = appI[@"ApplicationSINF"];
        
        if (SINF)
        {
            CAApplication *app=[[CAApplication alloc]initWithAppInfo:@{@"ApplicationContainer":container,@"ApplicationDirectory":appPath,@"ApplicationDisplayName":displayName,@"ApplicationName":[[appPath lastPathComponent]stringByReplacingOccurrencesOfString:@".app" withString:@""],@"RealUniqueID":[container lastPathComponent],@"ApplicationBasename":[appPath lastPathComponent],@"ApplicationVersion":version,@"ApplicationBundleID":bundleID,@"ApplicationSINF":SINF,@"ApplicationExecutableName":executableName,@"MinimumOSVersion":minimumOSVersion}];
            
            [returnArray addObject:app];
        }
    }
	
	if ([returnArray count] == 0)
		return nil;
	
    if (sort) {
        NSSortDescriptor *sorter = [[NSSortDescriptor alloc]
                                    initWithKey:@"applicationName"
                                    ascending:YES
                                    selector:@selector(localizedCaseInsensitiveCompare:)];
        NSArray *sortDescriptors = [NSArray arrayWithObject: sorter];
        [returnArray sortUsingDescriptors:sortDescriptors];
    }
    
    //caching is good
    NSMutableArray *cacheArray = [NSMutableArray new];
    for (CAApplication *app in returnArray) {
        [cacheArray addObject:[app dictionaryRepresentation]];
    }
    
    if (cacheArray.count>0) {
        [cacheArray writeToFile:applistCachePath atomically:YES];
    }
    
	return (NSArray *) returnArray;
}

@implementation CAApplicationsController

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static CAApplicationsController* shared = nil;
    dispatch_once(&pred, ^{
        shared = [CAApplicationsController new];
    });
    return shared;
}

- (NSArray *)installedApps
{
    if ([NSFileManager.defaultManager fileExistsAtPath:applistCachePath])
    {
        //check mod. date;
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:applistCachePath error:nil];
        
        NSUInteger modifTime = (NSUInteger)[[attributes fileModificationDate] timeIntervalSince1970]; //mins yo
        NSUInteger currentTime = (NSUInteger)[[NSDate date] timeIntervalSince1970]/60; //mins yo
        
        if ((currentTime-modifTime) > 5) {
            return get_application_list(YES);
        }

        NSArray *cachedAppsInfo = [NSArray arrayWithContentsOfFile:applistCachePath];
        
        NSMutableArray *appsArray = [NSMutableArray new];
        
        for (NSDictionary *appInfo in cachedAppsInfo) {
            CAApplication *app = [[CAApplication alloc]initWithAppInfo:appInfo];
            [appsArray addObject:app];
        }
        
        return appsArray;
        
    }
    
    return get_application_list(YES);
}

- (NSArray *)crackedApps
{
    NSString *crackedPath = [NSString stringWithFormat:@"%@/", [[Prefs sharedInstance] ipaDirectory]];
    NSArray *array=[[NSArray alloc]initWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:crackedPath error:nil]];
    NSMutableArray *paths=[[NSMutableArray alloc]init];
    for (int i=0; i<array.count; i++) {
        if (![[array[i] pathExtension] caseInsensitiveCompare:@"ipa"])
            [paths addObject:array[i]];
    }
    return [paths copy];
}

@end



