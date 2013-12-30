//
//  Cracker.m
//  Clutch
//
//  Created by DilDog on 12/22/13.
//
//

#import "Cracker.h"
#import "CAApplication.h"
#import "out.h"

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

-(BOOL)crackBinary {
    
}

// createPartialCopy
// copies only the files required for cracking an application to a staging area

-(BOOL)createPartialCopy:(NSString *)outdir withApplicationDir:(NSString *)appdir withMainExecutable:(NSString *)mainexe
{
    // Create output directory
    if(!forceCreateDirectory(outdir))
    {
        return NO;
    }
    
    // XXX: This, only if necessary: Get sandbox folder
    //NSString *topleveldir=[appdir stringByDeletingLastPathComponent];
    //NSString *appdirprefix=[appdir lastPathComponent];
    
    // Get top level .app folder
    NSString *topleveldir=[appdir copy];
    
    // Files required for cracking
    NSMutableArray *files=[[NSMutableArray alloc] init];
    [files addObject:@"_CodeSignature/CodeResources"];
    [files addObject:[NSString stringWithFormat:@"SC_Info/%@.sinf", mainexe]];
    [files addObject:[NSString stringWithFormat:@"SC_Info/%@.supp", mainexe]];
    [files addObject:mainexe];
    
    //XXX:[files addObject:[NSString stringWithFormat:@"%@/_CodeSignature/CodeResources", appdirprefix]];
    //XXX:[files addObject:[NSString stringWithFormat:@"%@/SC_Info/%@.sinf", appdirprefix, mainexe]];
    //XXX:[files addObject:[NSString stringWithFormat:@"%@/SC_Info/%@.supp", appdirprefix, mainexe]];
    //XXX:[files addObject:[NSString stringWithFormat:@"%@/%@", appdirprefix, mainexe]];
    //XXX:[files addObject:[NSString stringWithFormat:@"%@/Info.plist", appdirprefix];
    //XXX:[files addObject:@"iTunesMetadata.plist"];
    //XXX:[files addObject:@"iTunesArtwork"];
    
    NSEnumerator *e = [files objectEnumerator];
    NSString *file;
    while(file = [e nextObject])
    {
        if(!copyFile([NSString stringWithFormat:@"%@/%@", topleveldir, file],
                     [NSString stringWithFormat:@"%@/%@", outdir, file]))
        {
            forceRemoveDirectory(outdir);
            return NO;
        }
    }
    
    [topleveldir release];
    [files release];
    
    return YES;
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
    
    #warning binaryPath might be wrong, please check  <===== fixed
    
    _binaryPath = [[app.applicationContainer stringByAppendingPathComponent:app.appDirectory] stringByAppendingPathComponent:app.applicationExecutableName];
    
    _binary = [[CABinary alloc] initWithBinary:_binaryPath];
    DebugLog(@"binaryPath: %@", _binaryPath);
    return YES;
}

-(BOOL) execute {
    //1. dump binary
    NSError* error;
    if (![_binary crackBinaryToFile:_tempBinaryPath error:&error]) {
        DEBUG("error: could not crack binary")
        return NO;
    }
    [self packageIPA];
    
}
-(BOOL)packageIPA {
#warning TODO - not implemented
    //fake iTunesMetaData, SC_Info
    //zip
    return NO;
}
-(BOOL)prepareFromSpecificExecutable:(NSString *)exepath returnDescription:(NSMutableString *)description
{
    // Create the app description
    _appDescription=[NSString stringWithFormat:@"%@",exepath];
    
    return YES;
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
