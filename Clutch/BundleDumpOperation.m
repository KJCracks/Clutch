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
#import "Device.h"

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
        
        cpu_type_t _localCPUType = [Device cpu_type];
        cpu_subtype_t _localCPUSubtype = [Device cpu_subtype];
        
        NSFileManager *_fileManager = [NSFileManager defaultManager];
        
        Binary *originalBinary = _application.executable;
        
        Dumper *_dumper = [[Dumper alloc]initWithBinary:originalBinary];

        _binaryDumpPath = [originalBinary.workingPath stringByAppendingPathComponent:originalBinary.binaryPath.lastPathComponent];
        
        [_fileManager createDirectoryAtPath:_binaryDumpPath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:nil];
        
        [_fileManager copyItemAtPath:originalBinary.binaryPath toPath:_binaryDumpPath error:nil];
        
        NSFileHandle *_handle = [[NSFileHandle alloc]initWithFileDescriptor:fileno(fopen(_binaryDumpPath.UTF8String, "r+"))];
        
        struct thin_header headers[4];
        uint32_t numHeaders = 0;
        
        headersFromBinary(headers, _handle.availableData, &numHeaders);
        
        if (numHeaders == 0) {
            LOG("No compatible architecture found");
        }
        
        BOOL isFAT = numHeaders > 1;

        NSInteger dumpCount = 0;
        
        NSMutableArray *_headersToStrip = [NSMutableArray new];
        
        struct thin_header* compatibleArch = NULL;
        
        for (uint32_t i = 0; i < numHeaders; i++) {
            
            struct thin_header macho = headers[i];
            
            if (!isFAT) {
                if (macho.header.cputype == CPU_TYPE_ARM64)
                {
                    if (_localCPUType == CPU_TYPE_ARM64) {
                        if ([_dumper dump64bitFromFileHandle:&_handle machHeader:&macho])
                            dumpCount++;
                    }else
                        NSLog(@"Can't dump 64bit binary on 32bit device");
                    
                }else if ((_localCPUType == CPU_TYPE_ARM64) || (_localCPUSubtype >= macho.header.cpusubtype)) {
                    if ([_dumper dump32bitFromFileHandle:&_handle machHeader:&macho])
                        dumpCount++;
                }else
                {
                    NSLog(@"Can't dump 32bit %@ binary on 32bit %u device",[_dumper readableArchFromHeader:macho],_localCPUSubtype);
                }
            
            }else {
                
                if (macho.header.cputype == CPU_TYPE_ARM64)
                {
                    if (_localCPUType == CPU_TYPE_ARM64) {
                        if ([_dumper dump64bitFromFileHandle:&_handle machHeader:&macho])
                            dumpCount++;
                        else
                            return [self completeOperation];
                    }else
                        [_headersToStrip addObject:[NSValue value:&macho withObjCType:@encode(struct thin_header)]];
                    
                }else
                {
                    // oldschool bae
                    switch ([Device compatibleWith:&macho.header])
                    {
                        case COMPATIBLE:
                        {
                            if ([_dumper dump32bitFromFileHandle:&_handle machHeader:&macho])
                            {
                                dumpCount++;
                                compatibleArch = &macho;
                            }
                            else
                                return [self completeOperation];
                            break;
                        }
                        case NOT_COMPATIBLE:
                        {
                            NSLog(@"arch %@ is not compatible with this device!",[_dumper readableArchFromHeader:macho]);
                            [_headersToStrip addObject:[NSValue value:&macho withObjCType:@encode(struct thin_header)]];
                            break;
                        }
                        case COMPATIBLE_SWAP:
                        {
                           /* NSString* stripPath;
                            
                            if (originalBinary.hasARM64Slice) {
                                stripPath = [_dumper stripArch:macho.header.cpusubtype];
                            }else {
                                //stripPath = [_dumper swapArch:macho.header.cpusubtype];
                            }
                            
                            if (stripPath == NULL)
                            {
                                NSLog(@"error stripping/swapping binary!");
                                return [self completeOperation];
                            }
                            
                            NSFileHandle *_stripHandle = [[NSFileHandle alloc]initWithFileDescriptor:fileno(fopen(stripPath.UTF8String, "r+"))];

                            
                            //at this point newbinary is not fopen()'d  - should it be?
                            
                            if (![_dumper dump32bitFromFileHandle:&_stripHandle machHeader:&macho])
                            {
                                [_stripHandle closeFile];
                                // Dumping failed
                                
                                NSLog(@"Cannot crack stripped %@ portion of binary.", [_dumper readableArchFromHeader:macho]);
                                
                                
                                return [self completeOperation];
                            }
                            [_stripHandle closeFile];

                            //[_dumper swapBack:stripPath];
                            
                            compatibleArch = &macho;*/
                            
                            break;
                        }
                    }
                }
                
            }
            
        }
        
        [_handle closeFile];
        
        for (NSValue *valueWithArch in _headersToStrip) {
            struct thin_header stripArch;
            [valueWithArch getValue:&stripArch];
            [_dumper removeArchitecture:&stripArch];
        }
        
        
        if (dumpCount == (numHeaders-_headersToStrip.count))
        {
            NSString *_localPath = [originalBinary.binaryPath stringByReplacingOccurrencesOfString:_application.parentBundle?_application.parentBundle.bundleContainerURL.path:_application.bundleContainerURL.path withString:@""];
            
            [@{_binaryDumpPath:_localPath} writeToFile:[originalBinary.workingPath stringByAppendingPathComponent:@"filesToAdd.plist"] atomically:YES];
        }
        
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
