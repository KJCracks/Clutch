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
#import "ZipOperation.h"

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
        dispatch_async(dispatch_get_main_queue(), ^{
            CFRunLoopStop(CFRunLoopGetCurrent());
        });
        
    };
    
    // If the operation is not canceled, begin executing the task.
    [self willChangeValueForKey:@"isExecuting"];
    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)main {
    @try {
        
        if (_onlyBinaries) {
            
            NSDirectoryEnumerator *dirEnumerator = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:_application.workingPath] includingPropertiesForKeys:@[NSURLNameKey,NSURLIsDirectoryKey] options:0 errorHandler:^BOOL(NSURL *url, NSError *error) {
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
                        [plists addObject:theURL.path];
                    }
                }
            }
            
            __block BOOL status = plists.count == self.expectedBinariesCount;
            
            if (status) {
                SUCCESS_OUT(@"Finished dumping %@ to %@", _application.bundleIdentifier, _application.workingPath);
            }
            else {
                ERROR(@"Failed to dump %@ :(", _application.bundleIdentifier);
                exit(1);
            }
            
            [self completeOperation];
            
            return;
        }
        
        NSString *_zipFilename = _application.zipFilename;
        
        if (_application.parentBundle) {
            NSLog(@"Zipping %@",_application.bundleURL.lastPathComponent);
        }
        
        if (_archive == nil) {
            _archive = [[ZipArchive alloc] init];
            [_archive CreateZipFile2:[_application.workingPath stringByAppendingPathComponent:_zipFilename] append:YES];
        }
        
        NSDirectoryEnumerator *dirEnumerator = [NSFileManager.defaultManager enumeratorAtURL:[NSURL fileURLWithPath:_application.workingPath] includingPropertiesForKeys:@[NSURLNameKey,NSURLIsDirectoryKey] options:0 errorHandler:^BOOL(NSURL *url, NSError *error) {
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
#if PRINT_ZIP_LOGS
                        gbprintln(@"Added %@",zipPath);
#endif
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
        
        NSString *_ipaPath = [@"/private/var/mobile/Documents/Dumped" stringByAppendingPathComponent:_zipFilename];
        
        if (!status) {
            // remove .ipa if failed
            [[NSFileManager defaultManager]removeItemAtPath:[_application.workingPath stringByAppendingPathComponent:_zipFilename] error:nil];
        }else {
            [[NSFileManager defaultManager] createDirectoryAtPath:@"/private/var/mobile/Documents/Dumped" withIntermediateDirectories:YES attributes:nil error:nil];
            
            NSURL *ipaSrcURL = [NSURL fileURLWithPath:[_application.workingPath stringByAppendingPathComponent:_zipFilename]];
            NSError *anError;
            if ([[NSFileManager defaultManager] fileExistsAtPath:_ipaPath]) {
                for (int i = 2; i < 999; ++i) {
                    NSFileManager *fileMgr = [NSFileManager defaultManager];
                    NSString *newName =
                    [_ipaPath.lastPathComponent.stringByDeletingPathExtension
                     stringByAppendingFormat:@"-%i.%@", i, _ipaPath.pathExtension];
                    NSString *currentFile = [_ipaPath.stringByDeletingLastPathComponent
                                             stringByAppendingPathComponent:newName];
                    BOOL fileExists = [fileMgr fileExistsAtPath:currentFile];
                    if (!fileExists) {
                        _ipaPath = currentFile;
                        if (![[NSFileManager defaultManager]
                              moveItemAtURL:ipaSrcURL
                              toURL:[NSURL fileURLWithPath:currentFile]
                              error:&anError]) {
                            NSLog(@"Failed to move from %@ to %@ with error %@", ipaSrcURL,
                                  [NSURL fileURLWithPath:currentFile], anError);
                        }
                        break;
                    }
                }
            } else {
                if (![[NSFileManager defaultManager]
                      moveItemAtURL:ipaSrcURL
                      toURL:[NSURL fileURLWithPath:_ipaPath]
                      error:&anError]) {
                    NSLog(@"Failed to move from %@ to %@ with error %@", ipaSrcURL,
                          [NSURL fileURLWithPath:_ipaPath], anError);
                }
            }
        }
        
        gbprintln(@"%@: %@",status?@"DONE":@"FAILED",status?_ipaPath:_application);
        
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
    CFRunLoopStop(CFRunLoopGetCurrent());
}

-(NSUInteger)hash {
    return 4201234;
}

@end
