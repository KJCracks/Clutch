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
    
    __weak Application *_app = _application;
    
    self.completionBlock = ^{
        NSLog(@"DONE: %@",_app.workingPath);
    };
    
    // If the operation is not canceled, begin executing the task.
    [self willChangeValueForKey:@"isExecuting"];
    [NSThread detachNewThreadSelector:@selector(main) toTarget:self withObject:nil];
    _executing = YES;
    [self didChangeValueForKey:@"isExecuting"];
}

- (void)main {
    @try {
        
#warning todo
        
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
