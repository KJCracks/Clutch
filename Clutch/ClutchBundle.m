//
//  ClutchBundle.m
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "ClutchBundle.h"

@interface ClutchBundle ()

@end

@implementation ClutchBundle

- (instancetype)initWithBundleInfo:(NSDictionary *)info
{
    if (self = [super initWithURL:info[@"BundleURL"]]) {
        _bundleContainerURL = [info[@"BundleContainer"] copy];
        _dumpQueue = [NSOperationQueue new];
    }
    
    return self;
}

- (void)prepareForDump {
    _executable = [[Binary alloc]initWithBundle:self];
}

- (void)dumpToDirectoryURL:(NSURL *)directoryURL
{
    if (_dumpQueue.operationCount)
        [_dumpQueue cancelAllOperations];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, bundleIdentifier: %@, bundleURL: %@>",NSStringFromClass([self class]),self,self.bundleIdentifier,self.bundleURL];
    //return [NSString stringWithFormat:@"<%@: %p, bundleIdentifier: %@, bundleURL: %@, executable: %@>",NSStringFromClass([self class]),self,self.bundleIdentifier,self.bundleURL,_executable];
}

@end
