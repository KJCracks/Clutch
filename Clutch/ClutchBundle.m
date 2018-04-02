//
//  ClutchBundle.m
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "ClutchBundle.h"
#import "ClutchPrint.h"
#import "optool.h"

@interface ClutchBundle ()

@end

@implementation ClutchBundle

- (nullable instancetype)initWithPath:(NSString *)path {
    return [self initWithBundleInfo:@{
        @"BundleURL" : [NSURL fileURLWithPath:path],
        @"BundleContainer" : NSNull.null,
        @"DisplayName" : NSNull.null,
    }];
}

- (nullable instancetype)initWithBundleInfo:(NSDictionary *)info {
    NSURL *url = info[@"BundleURL"];
    if (!url || [NSNull isEqual:url]) {
        return nil;
    }

    if ((self = [super initWithPath:url.path])) {
        _bundleContainerURL = [info[@"BundleContainer"] copy];
        if ([NSNull isEqual:_bundleContainerURL]) {
            return nil;
        }
        _displayName = [info[@"DisplayName"] copy];
        if ([NSNull isEqual:_displayName]) {
            return nil;
        }
        _dumpQueue = [NSOperationQueue new];
    }

    return self;
}

- (void)prepareForDump {
    _executable = [[Binary alloc] initWithBundle:self];

    KJPrintVerbose(@"Preparing to dump %@", _executable);
    KJPrintVerbose(@"Path: %@", self.executable.binaryPath);

    NSDictionary *ownershipInfo = @{NSFileOwnerAccountName : @"mobile", NSFileGroupOwnerAccountName : @"mobile"};

    [[NSFileManager defaultManager] setAttributes:ownershipInfo ofItemAtPath:self.executable.binaryPath error:nil];
}

- (void)dumpToDirectoryURL:(NSURL *)directoryURL {
    CLUTCH_UNUSED(directoryURL);
    if (_dumpQueue.operationCount)
        [_dumpQueue cancelAllOperations];
}

- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<%@: %p, bundleIdentifier: %@, bundleURL: %@>",
                                      NSStringFromClass([self class]),
                                      (void *)self,
                                      self.bundleIdentifier,
                                      self.bundleURL];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ bundleID: %@>",
                                      self.bundlePath.lastPathComponent.stringByDeletingPathExtension,
                                      self.bundleIdentifier];
}

@end
