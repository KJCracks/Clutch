//
//  ClutchBundle.m
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "ClutchBundle.h"
#import "optool.h"
#import "ClutchPrint.h"

@interface ClutchBundle ()

@end

@implementation ClutchBundle

- (instancetype)initWithBundleInfo:(NSDictionary *)info
{
    if (self = [super initWithURL:info[@"BundleURL"]]) {
        _bundleContainerURL = [info[@"BundleContainer"] copy];
        _displayName = [info[@"DisplayName"] copy];
        _dumpQueue = [NSOperationQueue new];
    }
    
    return self;
}

- (void)prepareForDump {

    _executable = [[Binary alloc]initWithBundle:self];

    [[ClutchPrint sharedInstance] printVerbose:@"Preparing to dump %@", _executable];
	[[ClutchPrint sharedInstance] printVerbose:@"Path: %@", self.executable.binaryPath];
    
    NSDictionary *ownershipInfo = @{NSFileOwnerAccountName:@"mobile", NSFileGroupOwnerAccountName:@"mobile"};
    
    [[NSFileManager defaultManager] setAttributes:ownershipInfo ofItemAtPath:self.executable.binaryPath error:nil];
    
}

- (void)dumpToDirectoryURL:(NSURL *)directoryURL
{
    CLUTCH_UNUSED(directoryURL);
    if (_dumpQueue.operationCount)
        [_dumpQueue cancelAllOperations];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@: %p, bundleIdentifier: %@, bundleURL: %@>",NSStringFromClass([self class]),(void *)self,self.bundleIdentifier,self.bundleURL];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ bundleID: %@>",self.bundlePath.lastPathComponent.stringByDeletingPathExtension,self.bundleIdentifier];
}

@end
