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
    _workingDir = [NSString stringWithFormat:@"%@%@/Payload/%@", @"/tmp/clutch_", genRandStringLength(8), app.appDirectory];
    DebugLog(@"temporary directory %@", _workingDir);
    if (![[NSFileManager defaultManager] createDirectoryAtPath:_workingDir withIntermediateDirectories:YES attributes:@{NSFileOwnerAccountName:@"mobile",NSFileGroupOwnerAccountName:@"mobile"} error:NULL]) {
        
        printf("error: Could not create working directory\n");
        return nil;
    }
    _tempBinaryPath = [_workingDir stringByAppendingFormat:@"/%@", app.applicationExecutableName];
    DebugLog(@"tempBinaryPath: %@", _tempBinaryPath);
        
    _binaryPath = [[app.applicationContainer stringByAppendingPathComponent:app.appDirectory] stringByAppendingPathComponent:app.applicationExecutableName];
    
    _binary = [[CABinary alloc] initWithBinary:_binaryPath];
    
    _binary->overdriveEnabled = [[Prefs sharedInstance] boolForKey:@"useOverdrive"];
    
    DebugLog(@"binaryPath: %@", _binaryPath);
    return (!_binary)?NO:YES;
}

-(NSString*) generateIPAPath {
    NSString* ipapath;
    NSString *crackerName = [[Prefs sharedInstance] objectForKey:@"crackerName"];
    if (crackerName == nil) {
        crackerName = @"no-name-cracker";
    }
    
    ipapath = [NSString stringWithFormat:@"/var/root/Documents/Cracked/%@-v%@-%@-(%@).ipa", _app.applicationDisplayName, _app.applicationVersion, crackerName, [NSString stringWithUTF8String:CLUTCH_VERSION]];
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
        }
        crackOk = TRUE;
        DebugLog(@"crack operation ok!");
        printf("\nwaiting for zip thread\n");
    }];
   
    NSBlockOperation *zipOriginalOperation = [[NSBlockOperation alloc] init];
    __block __weak NSBlockOperation *zipOriginalweakOperation = zipOriginalOperation;
    
    [zipOriginalOperation addExecutionBlock:^{
        DebugLog(@"beginning zip operation");
        if ([[Prefs sharedInstance] useNativeZip]) {
            [zip zipOriginal:zipOriginalweakOperation];
        }
        else {
            [zip zipOriginalOld:zipOriginalweakOperation];
        }
        DebugLog(@"zip original ok");
        zipComplete = true;
    }];
    
    
    NSOperation *zipCrackedOperation = [NSBlockOperation blockOperationWithBlock:^{
        //check if crack was successful
        if (crackOk) {
            [self packageIPA];
            DebugLog(@"package IPA ok");
            [zip zipCracked];
            DebugLog(@"zip cracked ok");
            [zip->_archiver CloseZipFile2];
        }
        else {
            //stop the original zip
            //delete stuff
            //bye
            DebugLog(@"crack was not ok, welp");
        }
    }];
    [zipCrackedOperation addDependency:crackOperation];
    [zipCrackedOperation addDependency:zipOriginalOperation];
    
    [queue addOperation:zipCrackedOperation];
    [queue addOperation:crackOperation];
    [queue addOperation:zipOriginalOperation];
    [queue waitUntilAllOperationsAreFinished];
    return true;
}

-(void)packageIPA {

    NSString *crackerName = [[Prefs sharedInstance] objectForKey:@"crackerName"];
    if (crackerName == nil) {
        crackerName = @"no-name-cracker";
    }
    
    if (![[Prefs sharedInstance] boolForKey:@"removeMetadata"])
    {
        generateMetadata([_app.applicationContainer stringByAppendingPathComponent:@"iTunesMetadata.plist"], [[[_workingDir stringByDeletingLastPathComponent]stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"iTunesMetadata.plist"]);
    }
    
    if ([[Prefs sharedInstance] boolForKey:@"useOverdrive"]) {
        
        NSMutableCharacterSet *charactersToRemove = [NSMutableCharacterSet alphanumericCharacterSet];
        
        [charactersToRemove formUnionWithCharacterSet:[NSMutableCharacterSet nonBaseCharacterSet]];
        
        NSString *trimmedReplacement =
        [[[[Prefs sharedInstance] objectForKey:@"crackerName"] componentsSeparatedByCharactersInSet:[charactersToRemove invertedSet]]
         componentsJoinedByString:@""];

        
        NSString * OVERDRIVE_DYLIB_PATH = [NSString stringWithFormat:@"%@.dylib",[[Prefs sharedInstance] boolForKey:@"creditFile"]? trimmedReplacement :@"overdrive"];
        
        [[NSFileManager defaultManager] copyItemAtPath:@"/etc/clutch/overdrive.dylib" toPath:[_workingDir stringByAppendingPathComponent:OVERDRIVE_DYLIB_PATH] error:NULL];
        
    }
    
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
