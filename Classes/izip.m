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

- (instancetype)initWithCracker:(Cracker *)cracker {
    if (self = [super init]) {
        _cracker = cracker;
        zip_cracked = FALSE;
        zip_original = FALSE;
        _archiver = [[ZipArchive alloc] init];
        [_archiver CreateZipFile2:_cracker->_ipapath];
        NSLog(@"created IPAPAth %@", _cracker->_ipapath);
    }
    return self;
}

- (void) zipOriginal:(NSOperation*) operation {
    NSString* folder = _cracker->_app.applicationContainer;
    NSString* binary = _cracker->_app.applicationExecutableName;
    int compressionLevel = 0;
    BOOL isDir=NO;
    NSMutableArray *subpaths=nil;
    NSUInteger total = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:folder isDirectory:&isDir] && isDir){
        
        NSDirectoryEnumerator *dirEnumerator = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:folder] includingPropertiesForKeys:@[NSURLNameKey,NSURLIsDirectoryKey] options:nil errorHandler:^BOOL(NSURL *url, NSError *error) {
            return YES;
        }];
        
        subpaths = [NSMutableArray new];
        
        for (NSURL *theURL in dirEnumerator) {
            
            NSString *fullPath;
            [theURL getResourceValue:&fullPath forKey:NSURLPathKey error:NULL];
            
            NSMutableArray *comp = [NSMutableArray arrayWithArray:[fullPath pathComponents]];
            
            [comp removeObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, 5)]];
            
            if (comp.count>1) {
                if ((![comp[0] hasSuffix:@".app"])&&([comp[1] hasSuffix:@".app"])) {
                    [comp removeObjectAtIndex:0];
                }
            }
            
            
            NSMutableString *aNewPath = [NSMutableString new];
            
            for (int i = 0; i<comp.count; i++) {
                [aNewPath appendFormat:@"%@%@",i==0?@"":@"/",comp[i]];
            }
            
            
            [subpaths addObject:aNewPath];
        }
        
        total = [subpaths count];
        
    }
    
    NSString *appGUID = [folder lastPathComponent];
    
    for(NSString *path in subpaths) {
        
        if ([path hasPrefix:[appGUID stringByAppendingPathComponent:@"Documents"]]||[path hasPrefix:[appGUID stringByAppendingPathComponent:@"Library"]]||[path hasPrefix:[appGUID stringByAppendingPathComponent:@"tmp"]]||([path rangeOfString:@"SC_Info"].location != NSNotFound)||[path hasSuffix:binary])
        {
            continue;
        }
        
        NSString *longPath = [folder stringByAppendingPathComponent:path];
        
        if([fileManager fileExistsAtPath:longPath isDirectory:&isDir] && !isDir){
            
            [_archiver addFileToZip:longPath newname:[NSString stringWithFormat:@"Payload/%@", path] compressionLevel:compressionLevel];
            
        }
    }
    return;
    
}

- (void) zipCracked {
    NSString* folder = _cracker->_workingDir;
    NSString* payloadPath = [NSString stringWithFormat:@"Payload/%@.app/", _cracker->_app.applicationName];
    int compressionLevel = 0;
    BOOL isDir=NO;
    NSArray *subpaths=nil;
    NSUInteger total = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    BOOL exists = [fileManager fileExistsAtPath:folder isDirectory:&isDir];
    
    if (exists && isDir){
        subpaths = [fileManager subpathsAtPath:folder];
        total = [subpaths count];
    }
    
    
    for(NSString *path in subpaths){
        // Only add it if it's not a directory. ZipArchive will take care of those.
        NSString *longPath = [folder stringByAppendingPathComponent:path];
        NSLog(@"longpath %@ %@", longPath, path);
        if([fileManager fileExistsAtPath:longPath isDirectory:&isDir] && !isDir){
            [_archiver addFileToZip:longPath newname:[payloadPath stringByAppendingPathComponent:path] compressionLevel:compressionLevel];
        }
    }
    return;
}

@end


