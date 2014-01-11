//
//  Cracker.m
//  Clutch
//

#import "Cracker.h"
#import "CAApplication.h"
#import "out.h"
#import "imetadata.h"
#import "scinfo.h"
#import "izip.h"
#import "ZipArchive.h"
#import "API.h"

#import "Packager.h"

@interface Cracker () 

@end

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
    
    if (!file) {
        DEBUG("File string is nil");
        
        return nil;
    }
    
    [archiver CreateZipFile2:file];
    
    return archiver;
}


static NSString * genRandStringLength(int len) {
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%c", [letters characterAtIndex: arc4random()%[letters length]]];
    }
    
    return randomString;
}


// prepareFromInstalledApp
// set up application cracking from an installed application

-(BOOL)prepareFromInstalledApp:(CAApplication*)app
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
    DebugLog(@"temporary directory %@", _workingDir);
    MSG(CRACKING_CREATE_WORKING_DIR);
    if (![[NSFileManager defaultManager] createDirectoryAtPath:_workingDir withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile",NSFileGroupOwnerAccountName:@"mobile"} error:NULL]) {
        
        printf("error: Could not create working directory\n");
        return nil;
    }
    _tempBinaryPath = [_workingDir stringByAppendingFormat:@"/%@", app.applicationExecutableName];
    DebugLog(@"tempBinaryPath: %@", _tempBinaryPath);
        
    _binaryPath = [[app.applicationContainer stringByAppendingPathComponent:app.appDirectory] stringByAppendingPathComponent:app.applicationExecutableName];
    
    _binary = [[CABinary alloc] initWithBinary:_binaryPath];
    
    _binary->overdriveEnabled = [[Prefs sharedInstance] useOverdrive];
    
    DebugLog(@"binaryPath: %@", _binaryPath);
    return (!_binary)?NO:YES;
}

-(NSString*) generateIPAPath {
    NSString* ipapath;
    NSString *crackerName = [[Prefs sharedInstance] crackerName];
    
     NSString *crackedPath = [NSString stringWithFormat:@"%@/", [[Prefs sharedInstance] ipaDirectory]];
    if ([[Prefs sharedInstance] addMinOS]) {
        ipapath = [NSString stringWithFormat:@"%@%@-v%@-%@-iOS%@-(Clutch-%@).ipa", crackedPath, _app.applicationDisplayName, _app.applicationVersion, crackerName, _app.minimumOSVersion , [NSString stringWithUTF8String:CLUTCH_VERSION]];
    }
    else {
        ipapath = [NSString stringWithFormat:@"%@%@-v%@-%@-(Clutch-%@).ipa", crackedPath, _app.applicationDisplayName, _app.applicationVersion, crackerName, [NSString stringWithUTF8String:CLUTCH_VERSION]];
    }
    _ipapath = ipapath;
    return ipapath;
}

-(BOOL) execute {
    //1. dump binary
    __block NSError* error;
    __block BOOL* crackOk, *zipComplete = false;
    
    iZip* zip = [[iZip alloc] initWithCracker:self];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];

    NSBlockOperation *crackOperation = [NSBlockOperation blockOperationWithBlock:^{
        NSError* _error;
        DebugLog(@"beginning crack operation");
        if (![_binary crackBinaryToFile:_tempBinaryPath error:&_error]) {
            DebugLog(@"Failed to crack %@ with error: %@",_app.applicationDisplayName,error.localizedDescription);
            crackOk = FALSE;
            error = _error;
            MSG(PACKAGING_FAILED_KILL_ZIP);
            [zip->_zipTask terminate];
            DebugLog(@"terminate status %u", [zip->_zipTask terminationStatus]);
        }
        else {
            crackOk = TRUE;
            DebugLog(@"crack operation ok!");
            MSG(PACKAGING_WAITING_ZIP);
        }
       
    }];
    
    NSBlockOperation *apiBlockOperation = [NSBlockOperation blockOperationWithBlock:^{
        API* api = [[API alloc] initWithApp:_app];
        [api setObject:_ipapath forKey:@"IPAPAth"];
        [api setEnvironmentArgs];
    }];
   
    NSBlockOperation *zipOriginalOperation = [[NSBlockOperation alloc] init];
    __block __weak NSBlockOperation *zipOriginalweakOperation = zipOriginalOperation;
    
    [zipOriginalOperation addExecutionBlock:^{
        
        DebugLog(@"beginning zip operation");
        if ([[Prefs sharedInstance] useNativeZip]) {
            DebugLog(@"using native zip");
            [zip zipOriginal:zipOriginalweakOperation];
        }
        else {
            DebugLog(@"using old zip");
            NSString* zipDir = [NSString stringWithFormat:@"%@%@/", @"/tmp/clutch_", genRandStringLength(8)];
            if (![[NSFileManager defaultManager] createDirectoryAtPath:zipDir withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile",NSFileGroupOwnerAccountName:@"mobile"} error:NULL]) {
                DebugLog(@"could not create directory, huh?!");
            }
            DebugLog(@"container yo %@ %@", _app.applicationContainer, zipDir);
            [[NSFileManager defaultManager] createSymbolicLinkAtPath:[zipDir stringByAppendingString:@"Payload"] withDestinationPath:_app.applicationContainer error:NULL];
            
            [zip zipOriginalOld:zipOriginalweakOperation withZipLocation:zipDir];
            [[NSFileManager defaultManager] removeItemAtPath:zipDir error:nil];
        }
        DebugLog(@"zip original ok");
        zipComplete = true;
    }];
    
    
    NSOperation *zipCrackedOperation = [NSBlockOperation blockOperationWithBlock:^{
        //check if crack was successful
        if (crackOk) {
            MSG(PACKAGING_IPA);
            [self packageIPA];
            DebugLog(@"package IPA ok");
            [zip zipCracked];
            DebugLog(@"zip cracked ok");
            [zip->_archiver CloseZipFile2];
            //clean up
            MSG(PACKAGING_COMPRESSION_LEVEL);
        }
        else {
            //stop the original zip
            //delete stuff
            //bye
            DebugLog(@"crack was not ok, welp");
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
    return crackOk;
}

-(void)packageIPA {
    
    NSString* crackerName = [[Prefs sharedInstance] crackerName];
    
    if (![[Prefs sharedInstance] removeMetadata])
    {
        generateMetadata([_app.applicationContainer stringByAppendingPathComponent:@"iTunesMetadata.plist"], [[[_workingDir stringByDeletingLastPathComponent]stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesMetadata.plist"]);
    }
    
    if ([[Prefs sharedInstance] useOverdrive]) {
        
        NSMutableCharacterSet *charactersToRemove = [NSMutableCharacterSet alphanumericCharacterSet];
        
        [charactersToRemove formUnionWithCharacterSet:[NSMutableCharacterSet nonBaseCharacterSet]];
        
        NSString *trimmedReplacement =
        [[[[Prefs sharedInstance] crackerName] componentsSeparatedByCharactersInSet:[charactersToRemove invertedSet]]
         componentsJoinedByString:@""];

        NSString * OVERDRIVE_DYLIB_PATH = [NSString stringWithFormat:@"%@.dylib",[[Prefs sharedInstance] creditFile]? trimmedReplacement :@"overdrive"];
        
        [[NSFileManager defaultManager] copyItemAtPath:@"/etc/clutch/overdrive.dylib" toPath:[_workingDir stringByAppendingPathComponent:OVERDRIVE_DYLIB_PATH] error:NULL];
        
    }
    MSG(PACKAGING_ITUNESMETADATA);
    NSDictionary *imetadata_orig = [NSDictionary dictionaryWithContentsOfFile:[_app.applicationContainer stringByAppendingPathComponent:@"iTunesMetadata.plist"]];
    
    DebugLog(@"Creating fake SC_Info data...");
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


@end
