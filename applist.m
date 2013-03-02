#import "applist.h"

NSArray * get_application_list(BOOL sort, BOOL updates) {
	NSString *basePath = @"/var/mobile/Applications/";
	NSMutableArray *returnArray = [[NSMutableArray alloc] init];
	NSArray *apps = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:basePath error:NULL];
	
	if ([apps count] == 0) {
		return NULL;
	}
	
	NSEnumerator *e, *e2;
	e = [apps objectEnumerator];
	NSString *applicationDirectory;
	NSString *applicationSubdirectory;
	NSMutableDictionary *cache = [NSMutableDictionary dictionaryWithContentsOfFile:@"/var/cache/clutch.plist"];
	BOOL cflush = FALSE;
	if ((cache == nil) || (![cache count])) {
		cache = [NSMutableDictionary dictionary];
		cflush = TRUE;
	}
    NSMutableDictionary *versions;
	if (updates) {
        if (![[NSFileManager defaultManager] fileExistsAtPath:@"/etc/clutch_cracked.plist"]) {
            versions = [[NSMutableDictionary alloc] init];
        }
        else {
            versions = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/cache/clutch_cracked.plist"];
        }
    }
	NSDictionary *applicationDetailObject;
	NSString *bundleDisplayName, *applicationRealname, *bundleVersionString;
    
	while (applicationDirectory = [e nextObject]) {
		//if ([cache objectForKey:applicationDirectory] != nil) {
        //[returnArray addObject:[cache objectForKey:applicationDirectory]];
        //	} else {
        NSArray *sandboxPath = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[basePath stringByAppendingFormat:@"%@/", applicationDirectory] error:NULL];
        
        e2 = [sandboxPath objectEnumerator];
        while (applicationSubdirectory = [e2 nextObject]) {
            if ([applicationSubdirectory rangeOfString:@".app"].location == NSNotFound)
                continue;
            else {
                bundleDisplayName = [[NSDictionary dictionaryWithContentsOfFile:[basePath stringByAppendingFormat:@"%@/%@/Info.plist", applicationDirectory, applicationSubdirectory]] objectForKey:@"CFBundleDisplayName"];
                bundleVersionString = [[[NSDictionary dictionaryWithContentsOfFile:[basePath stringByAppendingFormat:@"%@/%@/Info.plist", applicationDirectory, applicationSubdirectory]] objectForKey:@"CFBundleVersion"] stringByReplacingOccurrencesOfString:@"." withString:@""];
                
                applicationRealname = [applicationSubdirectory stringByReplacingOccurrencesOfString:@".app" withString:@""];
                
                if (bundleDisplayName == nil) {
                    bundleDisplayName = applicationRealname;
                }
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:[basePath stringByAppendingFormat:@"%@/%@/SC_Info/", applicationDirectory, applicationSubdirectory]]) {
                    applicationDetailObject = [NSDictionary dictionaryWithObjectsAndKeys:
                                               [basePath stringByAppendingFormat:@"%@/", applicationDirectory], @"ApplicationBaseDirectory",
                                               [basePath stringByAppendingFormat:@"%@/%@/", applicationDirectory, applicationSubdirectory], @"ApplicationDirectory",
                                               bundleDisplayName, @"ApplicationDisplayName",
                                               applicationRealname, @"ApplicationName",
                                               applicationSubdirectory, @"ApplicationBasename",
                                               applicationDirectory, @"RealUniqueID",
                                               bundleVersionString, @"ApplicationVersion",
                                               nil];
                    
                    if (updates) {
                        if ([versions objectForKey:applicationRealname] != bundleVersionString) {
                            [returnArray addObject:applicationDetailObject];
                        }
                        
                    }
                    else {
                        [returnArray addObject:applicationDetailObject];
                    }
                    
                    [cache setValue:bundleDisplayName forKey:applicationDirectory];
                    cflush = TRUE;
                }
            }
        }
    }
	//}
	
	if (cflush) {
		[cache writeToFile:@"/var/cache/clutch.plist" atomically:TRUE];
	}
    
	if ([returnArray count] == 0) {
        [returnArray release];
		return NULL;
    }
	
	if (sort) {
		return (NSArray *)[returnArray sortedArrayUsingFunction:alphabeticalSort context:NULL];
    }
	return (NSArray *) returnArray;
}

NSComparisonResult alphabeticalSort(id one, id two, void *context) {
	return [[(NSDictionary *)one objectForKey:@"ApplicationName"] localizedCaseInsensitiveCompare:[(NSDictionary *)two objectForKey:@"ApplicationName"]];
}