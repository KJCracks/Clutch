#import "CAApplicationsController.h"
#import "MobileInstallation.h"
#import "out.h"

NSArray * get_application_list(BOOL sort) {
    
    NSMutableArray *returnArray = [NSMutableArray new];
    
    NSDictionary* options = @{@"ApplicationType":@"User",@"ReturnAttributes":@[@"CFBundleShortVersionString",@"CFBundleVersion",@"Path",@"CFBundleDisplayName",@"CFBundleExecutable",@"ApplicationSINF"]};
    
    NSDictionary *installedApps = MobileInstallationLookup(options);
    
    //DebugLog(@"installed apps %@", installedApps);
    
    for (NSString *bundleID in [installedApps allKeys]) {
        
        NSDictionary *appI=[installedApps objectForKey:bundleID];
        NSString *appPath=[[appI objectForKey:@"Path"]stringByAppendingString:@"/"];
        NSString *container=[[appPath stringByDeletingLastPathComponent]stringByAppendingString:@"/"];
        NSString *displayName=[appI objectForKey:@"CFBundleDisplayName"];
        NSString *executableName = [appI objectForKey:@"CFBundleExecutable"];
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
            CAApplication *app=[[CAApplication alloc]initWithAppInfo:@{@"ApplicationContainer":container,@"ApplicationDirectory":appPath,@"ApplicationDisplayName":displayName,@"ApplicationName":[[appPath lastPathComponent]stringByReplacingOccurrencesOfString:@".app" withString:@""],@"RealUniqueID":[container lastPathComponent],@"ApplicationBasename":[appPath lastPathComponent],@"ApplicationVersion":version,@"ApplicationBundleID":bundleID,@"ApplicationSINF":SINF,@"ApplicationExecutableName":executableName}];
            
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
    return get_application_list(YES);
}

- (NSArray *)crackedApps
{
    NSString *crackedPath = @"/var/root/Documents/Cracked";
    NSArray *array=[[NSArray alloc]initWithArray:[[NSFileManager defaultManager] contentsOfDirectoryAtPath:crackedPath error:nil]];
    NSMutableArray *paths=[[NSMutableArray alloc]init];
    for (int i=0; i<array.count; i++) {
        if (![[array[i] pathExtension] caseInsensitiveCompare:@"ipa"])
            [paths addObject:array[i]];
    }
    return [paths copy];
}

@end



