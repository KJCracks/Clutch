//
//  BundleDumpOperation.m
//  Clutch
//
//  Created by Anton Titkov on 11.02.15.
//
//

#import "BundleDumpOperation.h"
#import "Application.h"
#import "GBPrint.h"

#import "Dumper.h"

#import "defines.h"
#import "operations.h"
#import "NSData+Reading.h"
#import "headers.h"

@interface BundleDumpOperation ()
{
    ClutchBundle *_application;
    BOOL _executing, _finished;
    NSString *_binaryDumpPath;
}
@end

@implementation BundleDumpOperation

- (id)initWithBundle:(ClutchBundle *)application {
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
        
        NSFileManager *_fileManager = [NSFileManager defaultManager];
        
        Binary *originalBinary = _application.executable;
        
        _binaryDumpPath = [_application.workingPath stringByAppendingPathComponent:[_application.bundleIdentifier stringByAppendingPathComponent:_application.executablePath.lastPathComponent]];
        
        [_fileManager createDirectoryAtPath:_binaryDumpPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        
        [_fileManager copyItemAtPath:_application.executablePath toPath:_binaryDumpPath error:nil];
        
        NSData *_originalBinaryData = [NSData dataWithContentsOfFile:_binaryDumpPath];
        
        NSMutableData *_newBinaryData = _originalBinaryData.mutableCopy;
        
        struct thin_header headers[4];
        uint32_t numHeaders = 0;
        headersFromBinary(headers, _newBinaryData, &numHeaders);
        
        if (numHeaders == 0) {
            LOG("No compatible architecture found");
        }

        for (uint32_t i = 0; i < numHeaders; i++) {
            struct thin_header macho = headers[i];
            
            Dumper *_dumper = [[Dumper alloc]initWithBinary:originalBinary];
            
            if (macho.header.cputype == CPU_TYPE_ARM64)
            {
                // 64bit yoyo
                BOOL result = [_dumper dump64bitWithData:_newBinaryData machHeader:macho];
                
            }else
            {
                // oldschool bae
                
                if (macho.header.cpusubtype == CPU_SUBTYPE_ARM_V6) {
                    
                }else if (macho.header.cpusubtype == CPU_SUBTYPE_ARM_V7) {
                    
                }else if (macho.header.cpusubtype == CPU_SUBTYPE_ARM_V7S) {
                    
                }
                
                BOOL result = [_dumper dump32bitWithData:_newBinaryData machHeader:macho];
                
            }
            
        }

        [_newBinaryData writeToFile:_binaryDumpPath atomically:YES];
        
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
