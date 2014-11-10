#import "izip.h"

void zip(ZipArchive *archiver, NSString *folder, NSString* payloadPath, int compressionLevel) {
    
}

void zip_original(ZipArchive *archiver, NSString *folder, NSString *binary, NSString* zip,int compressionLevel)
{
    
    
}

@class iZip;
@protocol iZipDelegate <NSObject>

-(void)zipOriginalComplete;
-(void)zipCrackedComplete;

@end

@implementation iZip

- (instancetype)initWithCracker:(Cracker *)cracker
{
    if (self = [super init]) {
        _cracker = cracker;
        zip_cracked = FALSE;
        zip_original = FALSE;
        NSLog(@"created IPAPAth %@", _cracker->_ipapath);
    }
    
    return self;
}

- (void) zipOriginalOld:(NSOperation*) operation withZipLocation:(NSString*) location
{
    _zipTask = [[NSTask alloc] init];
    [_zipTask setLaunchPath:@"/bin/bash"];
    
    NSString* compressionArguments = [NSString stringWithFormat:@"-%u", _compressionLevel];
    NSString* args = [NSString stringWithFormat:@"cd %@; zip %@ -y -r -n .jpg:.JPG:.jpeg:.png:.PNG:.gif:.GIF:.Z:.gz:.zip:.zoo:.arc:.lzh:.rar:.arj:.mp3:.mp4:.m4a:.m4v:.ogg:.ogv:.avi:.flac:.aac \"%@\" Payload/* -x Payload/iTunesArtwork Payload/iTunesMetadata.plist \"Payload/Documents/*\" \"Payload/Library/*\" \"Payload/tmp/*\" \"Payload/*/%@\" \"Payload/*/SC_Info/*\" 2>&1> /dev/null", location, compressionArguments, _cracker->_ipapath, _cracker->_app.applicationExecutableName];
    
    if (![args writeToFile:@"/tmp/clutch-zip" atomically:YES encoding:NSUTF8StringEncoding error:nil])
    {
        DEBUG(@"could not write shell script to file, weird!");
    }
    
    NSArray* argArray = [[NSArray alloc] initWithObjects:@"/tmp/clutch-zip", nil];
    
    [_zipTask setArguments:argArray];
    [_zipTask launch];
    [_zipTask waitUntilExit];
    
    [argArray release];
    
}

- (void) zipOriginal:(NSOperation*) operation
{
    if (_archiver == nil) {
        _archiver = [[ZipArchive alloc] init];
        [_archiver CreateZipFile2:_cracker->_ipapath];
    }
    
    NSString* folder = _cracker->_app.applicationContainer;
    NSString* binary = _cracker->_app.applicationExecutableName;
    
    BOOL isDir=NO;
    
    NSMutableArray *subpaths=nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:folder isDirectory:&isDir] && isDir)
    {
        NSDirectoryEnumerator *dirEnumerator = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:folder] includingPropertiesForKeys:@[NSURLNameKey,NSURLIsDirectoryKey] options:nil errorHandler:^BOOL(NSURL *url, NSError *error) {
            DEBUG(@"%@", error);
            return YES;
        }];
        
        subpaths = [NSMutableArray new];
        
        for (NSURL *theURL in dirEnumerator)
        {
            
            NSString *fullPath;
            [theURL getResourceValue:&fullPath forKey:NSURLPathKey error:NULL];
            
            //NSLog(@"++++++++++++++++>%@",fullPath);
            
            NSMutableArray *comp = [NSMutableArray arrayWithArray:[fullPath pathComponents]];
            
            //fix iOS 8 bug
            if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0){
                [comp removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 8)]];
            }else{
                [comp removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 5)]];
            }
            
            if (comp.count > 1)
            {
                if ((![comp[0] hasSuffix:@".app"])&&([comp[1] hasSuffix:@".app"]))
                {
                    [comp removeObjectAtIndex:0];
                }
            }
            
            NSMutableString *aNewPath = [NSMutableString new];
            
            for (int i = 0; i<comp.count; i++)
            {
                [aNewPath appendFormat:@"%@%@",i==0?@"":@"/",comp[i]];
            }
            
            //NSLog(@"==============>%@",aNewPath);
            
            [subpaths addObject:aNewPath];
            
            [aNewPath release];
        }
    }
    
    NSString *appGUID = [folder lastPathComponent];
    
    for(NSString *path in subpaths)
    {
        
        //NSLog(@"------------------>%@",path);
        
        if ([path hasPrefix:[appGUID stringByAppendingPathComponent:@"Documents"]]||
            [path hasPrefix:[appGUID stringByAppendingPathComponent:@"Library"]]||
            [path hasPrefix:[appGUID stringByAppendingPathComponent:@"tmp"]]||
            ([path rangeOfString:@"SC_Info"].location != NSNotFound)||
            [path isEqualToString:@"iTunesArtwork"] ||
            [path isEqualToString:@"iTunesMetadata.plist"] ||
            [path hasSuffix:binary]
            )
        {
            continue;
        }
        //check plugin
        if (_cracker->_app.hasPlugin) {
            BOOL should_continue = NO;
            NSArray *pa = _cracker->_app.plugins;
            for (Extension *p in pa ) {
                if ([path hasSuffix:p.executableName]) {
                    should_continue = YES;
                    break;
                }
            }
            if (should_continue) {
                continue;
            }
        }
        
       /* if (_cracker->_app.hasFramework) {
            BOOL should_continue = NO;
            NSArray *pa = _cracker->_app.frameworks;
            for (Extension *p in pa ) {
                if ([path hasSuffix:p.executableName]) {
                    should_continue = YES;
                    break;
                }
            }
            if (should_continue) {
                continue;
            }
        }*/
        
        NSString *longPath = [folder stringByAppendingPathComponent:path];
        
        if([fileManager fileExistsAtPath:longPath isDirectory:&isDir] && !isDir)
        {
            [_archiver addFileToZip:longPath newname:[NSString stringWithFormat:@"Payload/%@", path] compressionLevel:_compressionLevel];
        }
    }
    
    [subpaths release];
    
    return;
}

- (void) zipCracked
{
    if (_archiver == nil)
    {
        _archiver = [[ZipArchive alloc] init];
        [_archiver openZipFile2:_cracker->_ipapath];
    }
    
    BOOL isDir=NO;
    
    NSArray *subpaths=nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    BOOL exists = [fileManager fileExistsAtPath:_cracker->_tempPath isDirectory:&isDir];
    DEBUG(@"working dir %@", _cracker->_tempPath);
    if (exists && isDir)
    {
        subpaths = [fileManager subpathsAtPath:_cracker->_tempPath];
        //total = [subpaths count]; DEAD_STORE
    }
    
    for(NSString *path in subpaths)
    {
        // Only add it if it's not a directory. ZipArchive will take care of those.
        NSString *longPath = [_cracker->_tempPath stringByAppendingPathComponent:path];
        //NSLog(@"longpath %@ %@", longPath, path);
        
        if([fileManager fileExistsAtPath:longPath isDirectory:&isDir] && !isDir)
        {
            //DEBUG(@"adding file %@", longPath);
            [_archiver addFileToZip:longPath newname:path compressionLevel:_compressionLevel];
        }
    }
    //DEBUG(@"subpaths %@", subpaths);
    return;
}
- (void) setCompressionLevel:(int) level
{
    _compressionLevel = level;
}

@end

