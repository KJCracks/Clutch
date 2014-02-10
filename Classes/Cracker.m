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
#import "YOPAPackage.h"
#import "Localization.h"
#import "ApplicationLister.h"

#import <xpc/xpc.h>
// ln -s /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include/xpc /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS7.0.sdk/usr/include/xpc
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

static BOOL forceRemoveDirectory(NSString *dirpath)
{
    BOOL isDir;
    NSFileManager *fileManager=[NSFileManager defaultManager];
    
    if(![fileManager fileExistsAtPath:dirpath isDirectory:&isDir])
    {
        if(![fileManager removeItemAtPath:dirpath error:NULL])
        {
            return NO;
        }
    }
    
    return YES;
}

static BOOL forceCreateDirectory(NSString *dirpath)
{
    BOOL isDir;
    NSFileManager *fileManager= [NSFileManager defaultManager];
    
    if([fileManager fileExistsAtPath:dirpath isDirectory:&isDir])
    {
        if(![fileManager removeItemAtPath:dirpath error:NULL])
        {
            return NO;
        }
    }
    
    if(![fileManager createDirectoryAtPath:dirpath withIntermediateDirectories:YES attributes:nil error:NULL])
    {
        return NO;
    }
    
    return YES;
}

static BOOL copyFile(NSString *infile, NSString *outfile)
{
    NSFileManager *fileManager= [NSFileManager defaultManager];
    
    if(![fileManager createDirectoryAtPath:[outfile stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:NULL])
    {
        return NO;
    }
    
    if(![fileManager copyItemAtPath:infile toPath:outfile error:NULL])
    {
        return NO;
    }
    
    return YES;
}

static ZipArchive * createZip(NSString *file) {
    ZipArchive *archiver = [[ZipArchive alloc] init];
    
    if (!file)
    {
        DEBUG(@"File string is nil");
        
        [archiver release];
        return nil;
    }
    
    [archiver CreateZipFile2:file];
    
    return archiver;
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
        _yopaPath = [NSString stringWithFormat:@"%@%@-v%@-%@-iOS%@-(Clutch-%@).7z.yopa.ipa", crackedPath, _app.applicationDisplayName, _app.applicationVersion, crackerName, _app.minimumOSVersion , [NSString stringWithUTF8String:CLUTCH_VERSION]];
    }
    else
    {
        _ipapath = [NSString stringWithFormat:@"%@%@-v%@-%@-(Clutch-%@).ipa", crackedPath, _app.applicationDisplayName, _app.applicationVersion, crackerName, [NSString stringWithUTF8String:CLUTCH_VERSION]];
         _yopaPath = [NSString stringWithFormat:@"%@%@-v%@-%@-(Clutch-%@).7z.yopa.ipa", crackedPath, _app.applicationDisplayName, _app.applicationVersion, crackerName, [NSString stringWithUTF8String:CLUTCH_VERSION]];
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
    
    if (!_yopaEnabled)
    {
        [zip setCompressionLevel:[[Preferences sharedInstance] compressionLevel]];
    }
    else
    {
        [zip setCompressionLevel:0];
    }
    
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
            
            if (_yopaEnabled)
            {
                DEBUG(@"YOPA enabled, generating YOPA file..");
                [self packageYOPA];
            }
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


void yopainstalld_peer_event_handler(Cracker* cracker, xpc_connection_t peer, xpc_object_t reply)
{
    
    xpc_type_t type = xpc_get_type(reply);
    if (xpc_get_type(reply) == XPC_TYPE_ERROR) {
        if (reply == XPC_ERROR_CONNECTION_INVALID)
        {
            NSLog(@"DAFUQ JUST HAPPENED. make sure you are r00t");
            xpc_connection_cancel(peer);
            exit(0);
            
        } else if (reply == XPC_ERROR_TERMINATION_IMMINENT)
        {
            NSLog(@"TERMINATOR!!!!!!!");
            //dunno what to do
            exit(0);
        }
    } else {
        assert(type == XPC_TYPE_DICTIONARY);
        
        NSString *status = [NSString stringWithUTF8String:xpc_dictionary_get_string(reply, "Status")];
        
        if ([status isEqualToString:@"Complete"]) {
            NSString* command = [NSString stringWithUTF8String:xpc_dictionary_get_string(reply, "Command")];
            if ([command isEqualToString:@"SaveVersion"]) {
                NSLog(@"save version ok");
            }
            else if ([command isEqualToString:@"GetVersions"]) {
                 xpc_object_t versions = xpc_dictionary_get_value(reply, "Versions");
                cracker->_yopaVersions = [[NSMutableArray alloc] init];
                 xpc_array_apply(versions, ^_Bool(size_t index, xpc_object_t value) {
                     [cracker->_yopaVersions addObject:[NSNumber numberWithInt:(int)value]];
                     return true;
                 });
            }
            else if ([command isEqualToString:@"GetPatchFiles"]) {
                xpc_object_t diff = xpc_dictionary_get_value(reply, "Diff");
                xpc_object_t addFiles = xpc_dictionary_get_value(diff, "AddFiles");
                xpc_object_t remFiles = xpc_dictionary_get_value(diff, "RemoveFiles");
                NSLog(@"Complete! YAY");
                cracker->_yopaAddFiles = [[NSMutableArray alloc] init];
                cracker->_yopaRemFiles = [[NSMutableArray alloc] init];
                xpc_array_apply(addFiles, ^_Bool(size_t index, xpc_object_t value) {
                    NSLog(@"Add Array value %s", (const char*)value);
                    [cracker->_yopaAddFiles addObject:[NSString stringWithUTF8String:(const char*)value]];
                    return true;
                });
                
                xpc_array_apply(remFiles, ^_Bool(size_t index, xpc_object_t value) {
                    NSLog(@"Remove Array value %s", (const char*)value);
                    [cracker->_yopaRemFiles addObject:[NSString stringWithUTF8String:(const char*)value]];
                    return true;
                });
               
            }
            xpc_connection_cancel(peer);
            
        }
        else if ([status isEqualToString:@"Error"])
        {
            
            if (xpc_dictionary_get_string(reply, "Error")) {
                //NSString *error = [NSString stringWithUTF8String:xpc_dictionary_get_string(reply, "Error")];
                NSLog(@"Error %@", [NSString stringWithUTF8String:xpc_dictionary_get_string(reply, "Error")]);
            }
            
            xpc_connection_cancel(peer);
            exit(0);
        }
        else
        {
            NSLog(@"%@",status);
        }
        
    }
    
}

-(void)packageYOPA
{
    
    YOPAPackage* package = [[YOPAPackage alloc] initWithPackagePath:_yopaPath];
    
    
    xpc_connection_t c = xpc_connection_create_mach_service("zorro.yopainstalld", NULL, 0);
    
    xpc_connection_set_event_handler(c, ^(xpc_object_t object) {
        //yopainstalld_peer_event_handler(self, c, object); //don't need dat?
    });
    
    xpc_connection_resume(c);
    
    // Messages are always dictionaries.
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "Command", "SaveVersion");
    xpc_dictionary_set_string(message, "AppBundle", _app.applicationBundleID.UTF8String);
    //xpc_dictionary_set_int64(message, "Version", 38);
    
    xpc_object_t SaveVersionResponse = xpc_connection_send_message_with_reply_sync(c, message);
    
    xpc_release(message);
    
    yopainstalld_peer_event_handler(self, c, SaveVersionResponse);
    
    xpc_release(SaveVersionResponse);

    // Messages are always dictionaries.
    message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "Command", "GetVersions");
    xpc_dictionary_set_string(message, "AppBundle", _app.applicationBundleID.UTF8String);
    
    xpc_object_t GetVersionsResponse = xpc_connection_send_message_with_reply_sync(c, message);
    
    xpc_release(message);
    
    yopainstalld_peer_event_handler(self, c, GetVersionsResponse);
    
    xpc_release(GetVersionsResponse);

    for (NSNumber* version in _yopaVersions) {
        if ([version isEqualToNumber:_app.appVersion]) {
            NSLog(@"same version! %@", version);
            continue;
        }
        
        // Messages are always dictionaries.
        message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(message, "Command", "GetPatchFiles");
        xpc_dictionary_set_string(message, "AppBundle", _app.applicationBundleID.UTF8String);
        xpc_dictionary_set_int64(message, "Version", [version intValue]);
        
        xpc_object_t GetPatchFilesResponse = xpc_connection_send_message_with_reply_sync(c, message);
        
        xpc_release(message);
        
        yopainstalld_peer_event_handler(self, c, GetPatchFilesResponse);
        
        xpc_release(GetPatchFilesResponse);
        
        ZipArchive* archive = [[ZipArchive alloc] init];
        NSString* archivePath = [_tempPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.zip", version]];
        [archive CreateZipFile2:archivePath];
        for (NSString* file in _yopaAddFiles) {
            NSLog(@"yopa add file patch %@", file);
            NSString* longPath = [_workingDir stringByAppendingPathComponent:file];
            [archive addFileToZip:longPath newname:file compressionLevel:0];
            
            [archive CloseZipFile2];
            
            YOPASegment* segment = [[YOPASegment alloc] initWithPatchPackage:archivePath withCompressionType:ZIP_COMPRESSION withBundleName:_app.applicationBundleID withVersion:version];
            
            [package addSegment:segment];
            [segment release];
        }
        
        [archive release];
        
    }
    

    
    //default zip segment
    YOPASegment* ipaSegment = [[YOPASegment alloc] initWithNormalPackage:_ipapath withCompressionType:ZIP_COMPRESSION withBundleName:_app.applicationBundleID];
    
    DEBUG(@"compressing to 7zip");
    
    NSString* tmp7z = [_tempPath stringByAppendingPathComponent:@"tmp.7z"];
    
    [self compressIPAto7z:tmp7z];
    
    YOPASegment* sevenZipSegment = [[YOPASegment alloc] initWithNormalPackage:tmp7z withCompressionType:SEVENZIP_COMPRESSION withBundleName:_app.applicationBundleID];
    
     DEBUG(@"adding segments");
    
    [package addSegment:ipaSegment];
    [ipaSegment release];
    [package addSegment:sevenZipSegment];
    [sevenZipSegment release];
    
    
    DEBUG(@"adding header");
    [package writeHeader];
    
    [package release];
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
        DEBUG(@"copy from %@ to %@", [_app.applicationContainer stringByAppendingString:@"iTunesMetadata.plist"], [[[_workingDir stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByAppendingString:@"/iTunesMetadata.plist"]);
        
        
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

-(NSString *)getAppDescription
{
    return _appDescription;
}

-(NSString *)getOutputFolder
{
    return _finaldir;
}

-(void)yopaEnabled:(BOOL)flag {
    _yopaEnabled = flag;
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
    
    NSDictionary *censorList = [NSDictionary dictionaryWithObjectsAndKeys:fake_email, @"appleId", fake_purchase_date, @"purchaseDate", nil];
    
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
                                      @"", @"asset-info", nil];
        for (id plistItem in metadataPlist)
        {
            if (([noCensorList objectForKey:plistItem] == nil) && ([censorList objectForKey:plistItem] == nil))
            {
                printf("\033[0;37;41mwarning: iTunesMetadata.plist item named '\033[1;37;41m%s\033[0;37;41m' is unrecognized\033[0m\n", [plistItem UTF8String]);
            }
        }
    }
    
    for (id censorItem in censorList)
    {
        [metadataPlist setObject:[censorList objectForKey:censorItem] forKey:censorItem];
    }
    
    [metadataPlist removeObjectForKey:@"com.apple.iTunesStore.downloadInfo"];
    
    DEBUG(@"metadataplist %@", metadataPlist);
    
    [metadataPlist writeToFile:output atomically:NO];
    
    utime(output.UTF8String, &oldtimes_metadata);
    utime(origPath.UTF8String, &oldtimes_metadata);
}

@end
