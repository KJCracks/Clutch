//
//  FinalizeDumpOperation.m
//  Clutch
//
//  Created by Anton Titkov on 12.02.15.
//
//

#import "FinalizeDumpOperation.h"
#import "ZipArchive.h"
#import "Application.h"
#import "GBPrint.h"

@interface FinalizeDumpOperation ()
{
    Application *_application;
    BOOL _executing, _finished;
    ZipArchive *_archive;
}
@end


@implementation FinalizeDumpOperation

- (instancetype)initWithApplication:(Application *)application {
    self = [super init];
    if (self) {
        _executing = NO;
        _finished = NO;
        _application = application;
    }
    return self;
}

- (BOOL)isConcurrent {
    return YES;
}

- (BOOL)isExecuting {
    return _executing;
}

- (BOOL)isFinished {
    return _finished;
}

- (void)start {
    // Always check for cancellation before launching the task.
    if ([self isCancelled])
    {
        // Must move the operation to the finished state if it is canceled.
        [self willChangeValueForKey:@"isFinished"];
        _finished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    self.completionBlock = ^{
        exit(0);
    };
    
    // If the operation is not canceled, begin executing the task.
    [self willChangeValueForKey:@"isExecuting"];
    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)main {
    @try {
        
        NSString *_zipFilename = _application.zipFilename;
        
        if (_application.parentBundle) {
            NSLog(@"Zipping %@",_application.bundleURL.lastPathComponent);
        }
        
        if (_archive == nil) {
            _archive = [[ZipArchive alloc] init];
            [_archive CreateZipFile2:[_application.workingPath stringByAppendingPathComponent:_zipFilename] append:YES];
        }
        
        // we need to enum _application.workingPath in order to find all filesToAdd.plist
        
        NSDirectoryEnumerator *dirEnumerator = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:_application.workingPath] includingPropertiesForKeys:@[NSURLNameKey,NSURLIsDirectoryKey] options:nil errorHandler:^BOOL(NSURL *url, NSError *error) {
            return YES;
        }];
        
        NSMutableArray *plists = [NSMutableArray new];
        
        for (NSURL *theURL in dirEnumerator)
        {
            NSNumber *isDirectory;
            [theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
            
            if ([theURL.lastPathComponent isEqualToString:@"filesToAdd.plist"]) {
                
                NSDictionary *dict = [NSDictionary dictionaryWithContentsOfURL:theURL];
                
                if (dict)
                {
                    for (NSString *key in dict.allKeys) {
                        NSString *zipPath = dict[key];
                        [_archive addFileToZip:key newname:zipPath];
                    }
                    
                    [plists addObject:theURL.path];
                }
            }
        }
        
        [_archive CloseZipFile2];
        
        // cleanup
        
#ifndef DEBUG
        for (NSString *path in plists)
            [[NSFileManager defaultManager]removeItemAtPath:path.stringByDeletingLastPathComponent error:nil];
#endif
        
        __block BOOL status = plists.count == self.expectedBinariesCount;
        
        gbprintln(@"%@: %@",status?@"DONE":@"FAILED",status?[_application.workingPath stringByAppendingPathComponent:_zipFilename]:_application);
        
        // Do the main work of the operation here.
        [self completeOperation];
    }
    @catch(...) {
        // Do not rethrow exceptions.
    }
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    _executing = NO;
    _finished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

@end
