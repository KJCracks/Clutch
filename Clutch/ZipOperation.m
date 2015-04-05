//
//  ZipOperation.m
//  Clutch
//
//  Created by Anton Titkov on 11.02.15.
//
//

#import "ZipOperation.h"
#import "ZipArchive.h"
#import "ClutchBundle.h"
#import "GBPrint.h"
#import "ProgressBar.h"

@interface ZipOperation ()
{
    ClutchBundle *_application;
    BOOL _executing, _finished;
    ZipArchive *_archive;
}
@end


@implementation ZipOperation

- (id)initWithApplication:(ClutchBundle *)application {
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
        
    };
    
    // If the operation is not canceled, begin executing the task.
    [self willChangeValueForKey:@"isExecuting"];
    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)main {
    @try {
        
        NSString *_zipFilename = _application.zipFilename, *_localPrefix = _application.zipPrefix;
        
        if (_application.parentBundle) {
            NSLog(@"Zipping %@",_application.bundleURL.lastPathComponent);
        }
        
        if (_archive == nil) {
            _archive = [[ZipArchive alloc] init];
            [_archive CreateZipFile2:[_application.workingPath stringByAppendingPathComponent:_zipFilename] append:(_application.parentBundle != nil)];
        }
        
        if (!_application.parentBundle && [[NSFileManager defaultManager]fileExistsAtPath:[_application.bundleContainerURL URLByAppendingPathComponent:@"iTunesArtwork" isDirectory:NO].path]) {
            [_archive addFileToZip:[_application.bundleContainerURL URLByAppendingPathComponent:@"iTunesArtwork" isDirectory:NO].path newname:@"iTunesArtwork"];
        }
        
        if (!_application.parentBundle && [[NSFileManager defaultManager]fileExistsAtPath:[_application.bundleContainerURL URLByAppendingPathComponent:@"iTunesMetadata.plist" isDirectory:NO].path]) {
            [_archive addFileToZip:[_application.bundleContainerURL URLByAppendingPathComponent:@"iTunesMetadata.plist" isDirectory:NO].path newname:@"iTunesMetadata.plist"];
        }
        
        NSDirectoryEnumerator *dirEnumerator = [NSFileManager.defaultManager enumeratorAtURL:_application.bundleURL includingPropertiesForKeys:@[NSURLNameKey,NSURLIsDirectoryKey] options:nil errorHandler:^BOOL(NSURL *url, NSError *error) {
            return YES;
        }];
        
        int count = [[dirEnumerator allObjects] count];
        int i;
        progress_message("Zipping..");
        for (NSURL *theURL in dirEnumerator)
        {
            i++;
            PERCENT((int)(ceil(i/count)));
            
            NSNumber *isDirectory;
            [theURL getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:nil];
            
            NSString *_localPath = [theURL.path stringByReplacingOccurrencesOfString:_application.bundleContainerURL.path withString:@""];
            
            NSArray *_pathComponents = _localPath.pathComponents;
            
            if (_pathComponents.count > 2) {
                if ([_pathComponents[2] isEqualToString:@"SC_Info"]||[_pathComponents[2] isEqualToString:@"Frameworks"]||[_pathComponents[2] isEqualToString:@"PlugIns"]) {
                    #if PRINT_ZIP_LOGS
                    gbprintln(@"Skipping %@",[_localPrefix stringByAppendingPathComponent:_localPath]);
                    #endif
                }
                else if (![isDirectory boolValue] && ![_pathComponents[2] isEqualToString:_application.executablePath.lastPathComponent]) {
                    [_archive addFileToZip:theURL.path newname:[_localPrefix stringByAppendingPathComponent:_localPath]];
                    #if PRINT_ZIP_LOGS
                    gbprintln(@"Added %@",[_localPrefix stringByAppendingPathComponent:_localPath]);
                    #endif
                }
                else {
                    #if PRINT_ZIP_LOGS
                    gbprintln(@"Skipping %@",[_localPrefix stringByAppendingPathComponent:_localPath]);
                    #endif
                }
            }
            else {
                #if PRINT_ZIP_LOGS
                gbprintln(@"Skipping %@",_localPath);
                #endif
            }
            
        }
        
        [_archive CloseZipFile2];
        
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
