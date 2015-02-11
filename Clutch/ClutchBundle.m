//
//  ClutchBundle.m
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "ClutchBundle.h"

@interface ClutchBundle ()
{
    NSOperationQueue *_dumpQueue;
}
@end

@implementation ClutchBundle

- (instancetype)initWithBundleInfo:(NSDictionary *)info
{
    
    if (self = [super initWithURL:info[@"BundleURL"]]) {
        _bundleContainerURL = [info[@"BundleContainer"] copy];
        _executable = [[Binary alloc]initWithBundle:self];
        _dumpQueue = [NSOperationQueue new];
    }
    
    return self;
}

- (BOOL)hasARMSlice
{
    return [self.executableArchitectures containsObject:[NSNumber numberWithInteger:CPU_TYPE_ARM]];
}

- (BOOL)hasARM64Slice
{
    return [self.executableArchitectures containsObject:[NSNumber numberWithInteger:CPU_TYPE_ARM64]];
}

- (void)dumpToDirectoryURL:(NSURL *)directoryURL
{
    if (_dumpQueue.operationCount)
        [_dumpQueue cancelAllOperations];
    
    
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, bundleIdentifier: %@, bundleURL: %@, executable: %@>",NSStringFromClass([self class]),self,self.bundleIdentifier,self.bundleURL,_executable];
}

@end
