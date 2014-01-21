//
//  Cracker.m
//  Clutch
//

#import "Cracker.h"
#import "Application.h"
#import "out.h"
#import "scinfo.h"
#import "izip.h"
#import "ZipArchive.h"
#import "API.h"
#import "YOPAPackage.h"
#import "Localization.h"
#import "Constants.h"

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
    // Create the app description
    _app = app;
    _appDescription = [NSString stringWithFormat:@"%@: %@ (%@)",
                     app.applicationBundleID,
                     app.applicationDisplayName,
                     app.applicationVersion];

    // Create working directory
    _tempPath = [NSString stringWithFormat:@"%@%@", @"/tmp/clutch_", genRandStringLength(8)];
    _workingDir = [NSString stringWithFormat:@"%@/Payload/%@", _tempPath, app.appDirectory];
    
    DEBUG(@"temporary directory %@", _workingDir);
    MSG(CRACKING_CREATE_WORKING_DIR);
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:_workingDir withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile",NSFileGroupOwnerAccountName:@"mobile"} error:NULL])
    {
        MSG(CRACKING_DIRECTORY_ERROR);
        return nil;
    }
    
    _tempBinaryPath = [_workingDir stringByAppendingFormat:@"/%@", app.applicationExecutableName];
    
    DEBUG(@"tempBinaryPath: %@", _tempBinaryPath);
        
    _binaryPath = [[app.applicationContainer stringByAppendingPathComponent:app.appDirectory] stringByAppendingPathComponent:app.applicationExecutableName];
    
    _binary = [[Binary alloc] initWithBinary:_binaryPath];
    
    _binary->overdriveEnabled = [[Preferences sharedInstance] useOverdrive];
    
    DEBUG(@"binaryPath: %@", _binaryPath);
    
    return (!_binary)?NO:YES;
}

-(NSString*) generateIPAPath
{
    NSString *crackerName = [[Preferences sharedInstance] crackerName];
    
     NSString *crackedPath = [NSString stringWithFormat:@"%@/", [[Preferences sharedInstance] ipaDirectory]];
    
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
    
    return _ipapath;
}

-(BOOL) execute
{
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
        NSError* _error;
        DEBUG(@"beginning crack operation");
    
        if (![_binary crackBinaryToFile:_tempBinaryPath error:&_error])
        {
            DEBUG(@"Failed to crack %@ with error: %@",_app.applicationDisplayName,error.localizedDescription);
        
            crackOk = FALSE;
            error = _error;
            
            MSG(PACKAGING_FAILED_KILL_ZIP);
            
            [zip->_zipTask terminate];
            
            DEBUG(@"terminate status %u", [zip->_zipTask terminationStatus]);
        }
        else
        {
            crackOk = TRUE;
         
            DEBUG(@"crack operation ok!");
            MSG(PACKAGING_WAITING_ZIP);
        }
    }];
    
    NSBlockOperation *apiBlockOperation = [NSBlockOperation blockOperationWithBlock:^{
        API* api = [[API alloc] initWithApp:_app];
        [api setObject:_ipapath forKey:@"IPAPAth"];
        [api setEnvironmentArgs];
        [api release];
    }];
   
    NSBlockOperation *zipOriginalOperation = [[NSBlockOperation alloc] init];
    __block __weak NSBlockOperation *zipOriginalweakOperation = zipOriginalOperation;
    
    [zipOriginalOperation addExecutionBlock:^{
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
    }];
    
    
    NSOperation *zipCrackedOperation = [NSBlockOperation blockOperationWithBlock:^{
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
        
        [[NSFileManager defaultManager] removeItemAtPath:_tempPath error:nil];
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
    
    return crackOk;
}

-(void)compressIPAto7z:(NSString*)packagePath {
    DEBUG(@"7zip compression");
    DEBUG(@"%@", [NSString stringWithFormat:@"7z a \"%@\" \"%@\"", packagePath, _ipapath]);
    system([[NSString stringWithFormat:@"7z a \"%@\" \"%@\"", packagePath, _ipapath] UTF8String]);
}

-(void)packageYOPA
{
    
    YOPAPackage* package = [[YOPAPackage alloc] initWithPackagePath:_yopaPath];
    
    //default zip segment
    YOPASegment* ipaSegment = [[YOPASegment alloc] initWithNormalPackage:_ipapath withCompressionType:ZIP_COMPRESSION withBundleName:_app.applicationBundleID];
    
    DEBUG(@"compressing to 7zip");
    
    NSString* tmp7z = [_tempPath stringByAppendingPathComponent:@"tmp.7z"];
    
    [self compressIPAto7z:tmp7z];
    
    YOPASegment* sevenZipSegment = [[YOPASegment alloc] initWithNormalPackage:tmp7z withCompressionType:SEVENZIP_COMPRESSION withBundleName:_app.applicationBundleID];
    
     DEBUG(@"adding segments");
    
    [package addSegment:ipaSegment];
    [package addSegment:sevenZipSegment];
    
    
    DEBUG(@"adding header");
    [package writeHeader];
    
    [package release];
}

-(void)packageIPA
{
    NSString* crackerName = [[Preferences sharedInstance] crackerName];
    
    if (![[Preferences sharedInstance] removeMetadata])
    {
        generateMetadata([_app.applicationContainer stringByAppendingPathComponent:@"iTunesMetadata.plist"], [[[_workingDir stringByDeletingLastPathComponent]stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesMetadata.plist"]);
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
    
    MSG(PACKAGING_ITUNESMETADATA);
    
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
    
    [metadataPlist writeToFile:output atomically:NO];
    
    utime(output.UTF8String, &oldtimes_metadata);
    utime(origPath.UTF8String, &oldtimes_metadata);
}

@end
