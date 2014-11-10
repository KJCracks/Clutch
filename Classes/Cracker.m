//
//  Cracker.m
//  Clutch
//

#import "Cracker.h"
#import "Application.h"
#import "scinfo.h"
#import "izip.h"
#import "ZipArchive.h"
#import "API.h"
#import "Localization.h"
#import "ApplicationLister.h"

#import <sys/stat.h>
#import <sys/types.h>
#import <utime.h>

@implementation Cracker

- (id)init
{
	self = [super init];
	if (self)
	{
		_appDescription = NULL;
		_workingDir = NULL;
	}
	return self;
}

-(void)dealloc
{
	if(_appDescription)
	{
		[_appDescription release];
	}
	if(_baselinedir)
	{
		[_baselinedir release];
	}
	if(_finaldir)
	{
		[_finaldir release];
	}
	if(_workingDir)
	{
		[_workingDir release];
	}
    
	[super dealloc];
}



static NSString * genRandStringLength(int len)
{
	NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
	NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
	for (int i=0; i<len; i++)
	{
		[randomString appendFormat: @"%c", [letters characterAtIndex: arc4random()%[letters length]]];
	}
    
	return randomString;
}

// prepareFromInstalledApp
// set up application cracking from an installed application
-(BOOL)prepareFromInstalledApp:(Application*)app
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/etc/clutch/overdrive.dylib" isDirectory:nil]) {
		if ([[Preferences sharedInstance] useOverdrive]) {
			printf("\nerror: could not find overdrive.dylib at /etc/clutch/overdrive.dylib, disabling overdrive!\n\n");
			[[Preferences sharedInstance] tempSetObject:@"NO" forKey:@"UseOverdrive"];
		}
	}
    
	DEBUG(@"------Prepairing from Installed App------");
	// Create the app description
	_app = app;
	_appDescription = [NSString stringWithFormat:@"%@: %@ (%@)",
	app.applicationBundleID,
	app.applicationDisplayName,
	app.applicationVersion];

	// Create working directory
	_tempPath = [NSString stringWithFormat:@"%@%@", @"/tmp/clutch_", genRandStringLength(8)];
	_workingDir = [NSString stringWithFormat:@"%@/Payload/%@", _tempPath, app.appDirectory];
    
	DEBUG(@"Temporary Directory: %@", _workingDir);
	MSG(CRACKING_CREATE_WORKING_DIR);
    
	if (![[NSFileManager defaultManager] createDirectoryAtPath:_workingDir withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile",NSFileGroupOwnerAccountName:@"mobile"} error:NULL])
	{
		MSG(CRACKING_DIRECTORY_ERROR);
		return nil;
	}
    
	_tempBinaryPath = [_workingDir stringByAppendingFormat:@"/%@", app.applicationExecutableName];
    
	DEBUG(@"Temporary Binary Path: %@", _tempBinaryPath);
        
	_binaryPath = [[app.applicationContainer stringByAppendingPathComponent:app.appDirectory] stringByAppendingPathComponent:app.applicationExecutableName];
    
	_binary = [[Binary alloc] initWithBinary:_binaryPath];
    
	_binary->overdriveEnabled = [[Preferences sharedInstance] useOverdrive];
    
	DEBUG(@"Binary Path: %@", _binaryPath);
    
	DEBUG(@"-------End Prepairing Installed App-----");
    
	return (!_binary) ? NO : YES;
}

-(NSString*) generateIPAPath
{
	DEBUG(@"------Generating Paths------");
	NSString *crackerName = [[Preferences sharedInstance] crackerName];
    
	NSString *crackedPath = [NSString stringWithFormat:@"%@/", [[Preferences sharedInstance] ipaDirectory]];
    
	if (![[NSFileManager defaultManager] fileExistsAtPath:[[Preferences sharedInstance] ipaDirectory]]) {
		DEBUG(@"Creating output directory..");
		[[NSFileManager defaultManager] createDirectoryAtPath:[[Preferences sharedInstance] ipaDirectory] withIntermediateDirectories:YES attributes:nil error:nil];
	}
    
	if ([[Preferences sharedInstance] addMinOS])
	{
		_ipapath = [NSString stringWithFormat:@"%@%@-v%@-%@-iOS%@-(Clutch-%@).ipa", crackedPath, _app.applicationDisplayName, _app.applicationVersion, crackerName, _app.minimumOSVersion , [NSString stringWithUTF8String:CLUTCH_VERSION]];
	}
	else
	{
		_ipapath = [NSString stringWithFormat:@"%@%@-v%@-%@-(Clutch-%@).ipa", crackedPath, _app.applicationDisplayName, _app.applicationVersion, crackerName, [NSString stringWithUTF8String:CLUTCH_VERSION]];
	}
    
	DEBUG(_ipapath);
    
	DEBUG(@"------End Generating Paths-----");
    
    
	return _ipapath;
}

-(BOOL) execute
{
    
	DEBUG(@"------Executing crack------")
    
    //1. dump binary
    __block NSError* error;
	__block BOOL* crackOk, *zipComplete = false;
    
	iZip* zip = [[iZip alloc] initWithCracker:self];
    

	[zip setCompressionLevel:[[Preferences sharedInstance] compressionLevel]];

    
	NSOperationQueue *queue = [[NSOperationQueue alloc] init];

	NSBlockOperation *crackOperation = [NSBlockOperation blockOperationWithBlock:^{
		DEBUG(@"------Crack Operation------");
		NSError* _error;
		DEBUG(@"beginning crack operation");
    
		if (![_binary crackBinaryToFile:_tempBinaryPath error:&_error])
		{
			//causing segfaults, bad.
			//DEBUG(@"Failed to crack %@ with error: %@",_app.applicationDisplayName, error.localizedDescription);
			DEBUG(@"Failed to crack %@",_app.applicationDisplayName);
			crackOk = FALSE;
			error = _error;
            
			MSG(PACKAGING_FAILED_KILL_ZIP);
            
			kill(zip->_zipTask.processIdentifier, SIGKILL);
			system("killall -9 zip");
            
			[zip->_zipTask terminate];
            
			@try {
				DEBUG(@"terminate status %u", [zip->_zipTask terminationStatus]);
			}
			@catch (NSException* e) {
				DEBUG(@"terminate ok, crashing is good (sometimes)");
			}
		}
		else
		{
            crackOk = TRUE;
            
            // Try crack any plugins
            if (_app.plugins)
            {
                NSArray *plugins = _app.plugins;
                printf("dumping: found plugins to crack\n");
                for (int i = 0; i < plugins.count; i++)
                {
                    Plugin *plugin = (Plugin *)plugins[i];
                    
                    Binary *pluginBinary = [[Binary alloc] initWithBinary:[plugin.pluginPath stringByAppendingString:plugin.pluginExecutableName]];
                    
                    NSString *tempPluginBinaryPath = [_workingDir stringByAppendingFormat:@"/PlugIns/%@/%@", [plugin.pluginPath lastPathComponent], plugin.pluginExecutableName];
                    NSLog(@"### TEMP PLUGIN PATH %@ ####", tempPluginBinaryPath);
                    NSError *error;
                    
                    printf("dumping: attempting to crack plugin: %s\n", plugin.pluginName.UTF8String);
                    if (![pluginBinary crackBinaryToFile:tempPluginBinaryPath error:&error])
                    {
                        if (error)
                        {
                            NSLog(@"Failed to crack plugin: %@ with error: %@", plugin.pluginExecutableName, error.description);
                            crackOk = FALSE;
                        }
                    }
                    else
                    {
                        printf("Plugin cracked ok?\n");
                    }
                }
                
            }
         
			DEBUG(@"crack operation ok!");
			MSG(PACKAGING_WAITING_ZIP);
			DEBUG(@"-----End Crack Op------");
		}
	}];
    
	NSBlockOperation *apiBlockOperation = [NSBlockOperation blockOperationWithBlock:^{
		API* api = [[API alloc] initWithApp:_app];
		[api setObject:_ipapath forKey:@"IPAPath"];
		[api setEnvironmentArgs];
		[api release];
	}];
   
	NSBlockOperation *zipOriginalOperation = [[NSBlockOperation alloc] init];
	__block __weak NSBlockOperation *zipOriginalweakOperation = zipOriginalOperation;
    
	[zipOriginalOperation addExecutionBlock:^{
		DEBUG(@"------Zip Operation------");
		DEBUG(@"beginning zip operation");
        
		if ([[Preferences sharedInstance] useNativeZip])
		{
			DEBUG(@"using native zip");
			[zip zipOriginal:zipOriginalweakOperation];
		}
		else
		{
			DEBUG(@"using old zip");
        
			NSString* zipDir = [NSString stringWithFormat:@"%@%@/", @"/tmp/clutch_", genRandStringLength(8)];
            
			if (![[NSFileManager defaultManager] createDirectoryAtPath:zipDir withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile",NSFileGroupOwnerAccountName:@"mobile"} error:NULL])
			{
				DEBUG(@"could not create directory, huh?!");
			}
            
			DEBUG(@"container yo %@ %@", _app.applicationContainer, zipDir);
            
			[[NSFileManager defaultManager] createSymbolicLinkAtPath:[zipDir stringByAppendingString:@"Payload"] withDestinationPath:_app.applicationContainer error:NULL];
            
			[zip zipOriginalOld:zipOriginalweakOperation withZipLocation:zipDir];
			[[NSFileManager defaultManager] removeItemAtPath:zipDir error:nil];
		}
        
		DEBUG(@"zip original ok");
		zipComplete = true;
		DEBUG(@"------End Zip Op------");
	}];
    
    
	NSOperation *zipCrackedOperation = [NSBlockOperation blockOperationWithBlock:^{
		DEBUG(@"------Zip Cracked Op------");
		//check if crack was successful
		if (crackOk)
		{
			MSG(PACKAGING_IPA);
            
			[self packageIPA];
            
			DEBUG(@"package IPA ok");
            
			[zip zipCracked];
            
			DEBUG(@"zip cracked ok");
            
			[zip->_archiver CloseZipFile2];
            
			//clean up
			MSG(PACKAGING_COMPRESSION_LEVEL, zip->_compressionLevel);
            
		}
		else
		{
			//stop the original zip
			//delete stuff
			//bye
			DEBUG(@"crack was not ok, welp");
			[[NSFileManager defaultManager] removeItemAtPath:_ipapath error:nil];
		}
        
		//[[NSFileManager defaultManager] removeItemAtPath:_tempPath error:nil];
		DEBUG(@"------End Zip Crack Op------");
	}];
    
	[zipCrackedOperation addDependency:crackOperation];
	[zipCrackedOperation addDependency:zipOriginalOperation];
	[zipCrackedOperation addDependency:apiBlockOperation];
    
	[queue addOperation:apiBlockOperation];
	[queue addOperation:zipCrackedOperation];
	[queue addOperation:crackOperation];
	[queue addOperation:zipOriginalOperation];
	[queue waitUntilAllOperationsAreFinished];
    
	[queue release];
    
	DEBUG(@"------End Execute Crack------");
    
	[[ApplicationLister sharedInstance] crackedApp:_app];
    
	DEBUG(@"Saved cracked app info!");
    
	return crackOk;
}

-(void)compressIPAto7z:(NSString*)packagePath {
	DEBUG(@"7zip compression");
	DEBUG(@"%@", [NSString stringWithFormat:@"7z a \"%@\" \"%@\"", packagePath, _ipapath]);
	system([[NSString stringWithFormat:@"7z a \"%@\" \"%@\"", packagePath, _ipapath] UTF8String]);
}


-(void)packageIPA
{
	NSString* crackerName = [[Preferences sharedInstance] crackerName];
    
	DEBUG(@"old metadata %@ %@", [_app.applicationContainer stringByAppendingPathComponent:@"iTunesMetadata.plist"], [[[_workingDir stringByDeletingLastPathComponent]stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesMetadata.plist"])
    
		if (([[Preferences sharedInstance] removeMetadata]) || ([[[Preferences sharedInstance] metadataEmail] length] > 0))
	{
		MSG(PACKAGING_ITUNESMETADATA);
		DEBUG(@"Generating fake iTunesMetadata");
		generateMetadata([_app.applicationContainer stringByAppendingPathComponent:@"iTunesMetadata.plist"], [[[_workingDir stringByDeletingLastPathComponent]stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesMetadata.plist"]);
	}
	else
	{
		//NSError *err;
		DEBUG(@"Moving iTunesMetadata");
		DEBUG(@"copy from %@ to %@", [_app.applicationContainer stringByAppendingString:@"iTunesMetadata.plist"], [[[_workingDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingString:@"iTunesMetadata.plist"]);
        
        
		[[NSFileManager defaultManager] copyItemAtPath:[_app.applicationContainer stringByAppendingPathComponent:@"iTunesMetadata.plist"] toPath:[[[_workingDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesMetadata.plist"] error:nil];
        
	}
    
	if ([[Preferences sharedInstance] useOverdrive])
	{
		NSMutableCharacterSet *charactersToRemove = [NSMutableCharacterSet alphanumericCharacterSet];
        
		[charactersToRemove formUnionWithCharacterSet:[NSMutableCharacterSet nonBaseCharacterSet]];
        
		NSString *trimmedReplacement =
			[[[[Preferences sharedInstance] crackerName] componentsSeparatedByCharactersInSet:[charactersToRemove invertedSet]]
				componentsJoinedByString:@""];

		NSString * OVERDRIVE_DYLIB_PATH = [NSString stringWithFormat:@"%@.dylib",[[Preferences sharedInstance] creditFile]? trimmedReplacement :@"overdrive"];
        
		[[NSFileManager defaultManager] copyItemAtPath:@"/etc/clutch/overdrive.dylib" toPath:[_workingDir stringByAppendingPathComponent:OVERDRIVE_DYLIB_PATH] error:NULL];
        
	}
    
	DEBUG(@"Copying iTunesArtwork");
	DEBUG(@"copy from %@, to %@", [_app.applicationContainer stringByAppendingString:@"iTunesArtwork"], [[[_workingDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesArtwork"]);
    
	[[NSFileManager defaultManager] copyItemAtPath:[_app.applicationContainer stringByAppendingString:@"iTunesArtwork"] toPath:[[[_workingDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesArtwork"] error:nil];
    
	NSDictionary *imetadata_orig = [NSDictionary dictionaryWithContentsOfFile:[_app.applicationContainer stringByAppendingPathComponent:@"iTunesMetadata.plist"]];
    
	if ([[Preferences sharedInstance] useOverdrive]) // Fix for #19
	{
		DEBUG(@"Creating fake SC_Info data...");
    
		// create fake SC_Info directory
		[[NSFileManager defaultManager] createDirectoryAtPath:[_workingDir stringByAppendingPathComponent:@"SF_Info"] withIntermediateDirectories:YES attributes:nil error:NULL];
        
		NSLog(@"DEBUG: made fake directory");
    
		// create fake SC_Info SINF file
		FILE *sinfh = fopen([[_workingDir stringByAppendingPathComponent:@"SF_Info"]stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.sinf", _app.applicationExecutableName]].UTF8String, "w");

		void *sinf = generate_sinf([imetadata_orig[@"itemId"] intValue], (char *)[crackerName UTF8String], [imetadata_orig[@"vendorId"] intValue]);
    
		fwrite(sinf, CFSwapInt32(*(uint32_t *)sinf), 1, sinfh);
		fclose(sinfh);
		free(sinf);
    
		// create fake SC_Info SUPP file
		FILE *supph = fopen([[_workingDir stringByAppendingPathComponent:@"SF_Info"]stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.supp", _app.applicationExecutableName]].UTF8String, "w");
		uint32_t suppsize;
		void *supp = generate_supp(&suppsize);
		fwrite(supp, suppsize, 1, supph);
		fclose(supph);
		free(supp);
	}
}

-(NSString *)getAppDescription
{
	return _appDescription;
}

-(NSString *)getOutputFolder
{
	return _finaldir;
}


void generateMetadata(NSString *origPath,NSString *output)
{
	DEBUG(@"generate metdata %@, %@", origPath, output);
    
	struct stat statbuf_metadata;
	stat(origPath.UTF8String, &statbuf_metadata);
	time_t mst_atime = statbuf_metadata.st_atime;
	time_t mst_mtime = statbuf_metadata.st_mtime;
    
	struct utimbuf oldtimes_metadata;
	oldtimes_metadata.actime = mst_atime;
	oldtimes_metadata.modtime = mst_mtime;
    
	NSString *fake_email;
	NSDate *fake_purchase_date = [NSDate dateWithTimeIntervalSince1970:1251313938];
    
	if (nil == (fake_email = [[Preferences sharedInstance] metadataEmail]))
	{
		fake_email = @"steve@rim.jobs";
	}
    
    
	NSMutableDictionary *metadataPlist = [NSMutableDictionary dictionaryWithContentsOfFile:origPath];
    
    NSDictionary *censorList = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                fake_email, @"appleId",
                                                                fake_purchase_date, @"purchaseDate",
                                                                @"", @"userName",
                                                                nil];
    
	if ([[Preferences sharedInstance] boolForKey:@"CheckMetadata"])
	{
		NSDictionary *noCensorList = [NSDictionary dictionaryWithObjectsAndKeys:
		@"", @"artistId",
		@"", @"artistName",
		@"", @"buy-only",
		@"", @"buyParams",
		@"", @"copyright",
		@"", @"drmVersionNumber",
		@"", @"fileExtension",
		@"", @"genre",
		@"", @"genreId",
		@"", @"itemId",
		@"", @"itemName",
		@"", @"gameCenterEnabled",
		@"", @"gameCenterEverEnabled",
		@"", @"kind",
		@"", @"playlistArtistName",
		@"", @"playlistName",
		@"", @"price",
		@"", @"priceDisplay",
		@"", @"rating",
		@"", @"releaseDate",
		@"", @"s",
		@"", @"softwareIcon57x57URL",
		@"", @"softwareIconNeedsShine",
		@"", @"softwareSupportedDeviceIds",
		@"", @"softwareVersionBundleId",
		@"", @"softwareVersionExternalIdentifier",
		@"", @"UIRequiredDeviceCapabilities",
		@"", @"softwareVersionExternalIdentifiers",
		@"", @"subgenres",
		@"", @"vendorId",
		@"", @"versionRestrictions",
		@"", @"com.apple.iTunesStore.downloadInfo",
		@"", @"bundleVersion",
		@"", @"bundleShortVersionString",
		@"", @"product-type",
		@"", @"is-purchased-redownload",
		@"", @"asset-info",
		@"", @"bundleDisplayName",
		nil];
		for (id plistItem in metadataPlist)
		{
			if (([noCensorList objectForKey:plistItem] == nil) && ([censorList objectForKey:plistItem] == nil))
			{
				printf("\033[0;37;41mwarning: iTunesMetadata.plist item named '\033[1;37;41m%s\033[0;37;41m' is unrecognized\033[0m\n", [plistItem UTF8String]);
				printf("\033[0;37;41mwarning: please report this to the devs so we can add it to our list.\033[0m\n");
			}
		}
	}
    
	for (id censorItem in censorList)
	{
		[metadataPlist setObject:[censorList objectForKey:censorItem] forKey:censorItem];
	}
    
	[metadataPlist removeObjectForKey:@"com.apple.iTunesStore.downloadInfo"];
    
	//DEBUG(@"metadataplist %@", metadataPlist);
    
	[metadataPlist writeToFile:output atomically:NO];
    
	utime(output.UTF8String, &oldtimes_metadata);
	utime(origPath.UTF8String, &oldtimes_metadata);
}

@end
