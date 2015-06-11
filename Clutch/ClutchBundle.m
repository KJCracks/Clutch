//
//  ClutchBundle.m
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "ClutchBundle.h"
#import "optool.h"

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
    NSLog(@"preparing for dump");
    _executable = [[Binary alloc]initWithBundle:self];
    
    // experimental
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:self.executable.binaryPath];
    
    thin_header headers[4];
    uint32_t numHeaders = 0;
    
    headersFromBinary(headers, data, &numHeaders);
    
    for (int i = 0; i < numHeaders; i++) {
        thin_header _thinHeader = headers[i];
        
        NSString *rpath = self.parentBundle ? [self.parentBundle.bundlePath stringByAppendingPathComponent:@"Frameworks"] : [self.bundlePath stringByAppendingPathComponent:@"Frameworks"] ;
        NSLog(@"checking rpath for %@", self.executable.binaryPath);
        insertRPATHIntoBinary(rpath, data, _thinHeader);
    }
    
    [data writeToFile:self.executable.binaryPath atomically:YES];
    
    NSDictionary *ownershipInfo = @{NSFileOwnerAccountName:@"mobile", NSFileGroupOwnerAccountName:@"mobile"};
    
    [[NSFileManager defaultManager] setAttributes:ownershipInfo ofItemAtPath:self.executable.binaryPath error:nil];
    
}

- (void)dumpToDirectoryURL:(NSURL *)directoryURL
{
    if (_dumpQueue.operationCount)
        [_dumpQueue cancelAllOperations];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@: %p, bundleIdentifier: %@, bundleURL: %@>",NSStringFromClass([self class]),self,self.bundleIdentifier,self.bundleURL];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ bundleID: %@>",self.bundlePath.lastPathComponent.stringByDeletingPathExtension,self.bundleIdentifier];
}

@end
