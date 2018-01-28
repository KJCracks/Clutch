//
//  Application.m
//  Clutch
//
//  Created by Anton Titkov on 09.02.2015.
//
//

#import "Application.h"
#import "BundleDumpOperation.h"
#import "ClutchPrint.h"
#import "Device.h"
#import "FinalizeDumpOperation.h"
#import "SCInfoBuilder.h"
#import "ZipOperation.h"

@interface Application () {
    NSUUID *_workingUUID;
    NSMutableArray *_frameworks;
    NSMutableArray *_extensions;
    NSMutableArray *_watchOSApps;
    NSString *_workingPath;
}
@end

@implementation Application

- (instancetype)initWithBundleInfo:(NSDictionary *)info {
    if (self = [super initWithBundleInfo:info]) {

        _workingUUID = [NSUUID new];
        _workingPath = [NSTemporaryDirectory()
            stringByAppendingPathComponent:[@"clutch" stringByAppendingPathComponent:_workingUUID.UUIDString]];

        [self reloadFrameworksInfo];
        [self reloadPluginsInfo];
        [self reloadWatchOSAppsInfo];
    }
    return self;
}

- (void)prepareForDump {
    [super prepareForDump];

    for (ClutchBundle *bundle in _frameworks)
        [bundle prepareForDump];

    for (ClutchBundle *bundle in _extensions)
        [bundle prepareForDump];

#ifdef DEBUG
    for (Application *bundle in _watchOSApps) {
        for (ClutchBundle *_watchOSApp in bundle.extensions) {
            [_watchOSApp prepareForDump];
        }
    }
#endif
}

- (BOOL)isAppleWatchApp {
    if ([self.infoDictionary[@"CFBundleSupportedPlatforms"] containsObject:@"WatchOS"] ||
        [self.infoDictionary[@"DTPlatformName"] isEqualToString:@"watchos"])
        return YES;

    return NO;
}

- (void)reloadWatchOSAppsInfo {
    _hasAppleWatchApp = NO;
    _watchOSApps = [NSMutableArray new];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL = [NSURL
        fileURLWithPath:[self.bundlePath stringByAppendingPathComponent:@"Watch"]]; // URL pointing to the directory you
                                                                                    // want to browse
    NSArray *keys = @[ NSURLIsDirectoryKey ];

    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:directoryURL
                                          includingPropertiesForKeys:keys
                                                             options:0
                                                        errorHandler:^(NSURL *url, NSError *error) {
                                                            CLUTCH_UNUSED(url);
                                                            CLUTCH_UNUSED(error);
                                                            // Handle the error.
                                                            // Return YES if the enumeration should continue after the
                                                            // error.
                                                            return YES;
                                                        }];

    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;

        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // handle error
        } else if (![(url.path).pathExtension caseInsensitiveCompare:@"app"] && isDirectory.boolValue) {
            Application *watchOSApp = [[Application alloc]
                initWithBundleInfo:@{@"BundleContainer" : url.URLByDeletingLastPathComponent, @"BundleURL" : url}];

            if (watchOSApp.isAppleWatchApp) {
                _hasAppleWatchApp = YES;
                watchOSApp.parentBundle = self;
                [_watchOSApps addObject:watchOSApp];
            }
        }
    }
}

- (void)reloadFrameworksInfo {
    _frameworks = [NSMutableArray new];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL =
        [NSURL fileURLWithPath:self.privateFrameworksPath]; // URL pointing to the directory you want to browse
    NSArray *keys = @[ NSURLIsDirectoryKey ];

    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:directoryURL
                                          includingPropertiesForKeys:keys
                                                             options:0
                                                        errorHandler:^(NSURL *url, NSError *error) {
                                                            CLUTCH_UNUSED(url);
                                                            CLUTCH_UNUSED(error);
                                                            // Handle the error.
                                                            // Return YES if the enumeration should continue after the
                                                            // error.
                                                            return YES;
                                                        }];

    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;

        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // handle error
        } else if (![(url.path).pathExtension caseInsensitiveCompare:@"framework"] && isDirectory.boolValue) {
            Framework *fmwk = [[Framework alloc]
                initWithBundleInfo:@{@"BundleContainer" : url.URLByDeletingLastPathComponent, @"BundleURL" : url}];
            if (fmwk) {

                fmwk.parentBundle = self;

                [_frameworks addObject:fmwk];
            }
        }
    }
}

- (void)reloadPluginsInfo {
    _extensions = [NSMutableArray new];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL =
        [NSURL fileURLWithPath:self.builtInPlugInsPath]; // URL pointing to the directory you want to browse
    NSArray *keys = @[ NSURLIsDirectoryKey ];

    NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:directoryURL
                                          includingPropertiesForKeys:keys
                                                             options:0
                                                        errorHandler:^(NSURL *url, NSError *error) {
                                                            CLUTCH_UNUSED(url);
                                                            CLUTCH_UNUSED(error);
                                                            // Handle the error.
                                                            // Return YES if the enumeration should continue after the
                                                            // error.
                                                            return YES;
                                                        }];

    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;

        if (![url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // handle error
        } else if (![(url.path).pathExtension caseInsensitiveCompare:@"appex"] && isDirectory.boolValue) {
            Extension *_extension = [[Extension alloc]
                initWithBundleInfo:@{@"BundleContainer" : url.URLByDeletingLastPathComponent, @"BundleURL" : url}];
            if (_extension) {

                _extension.parentBundle = self;
                [_extensions addObject:_extension];
            }
        }
    }
}

- (BOOL)dumpToDirectoryURL:(nullable NSURL *)directoryURL onlyBinaries:(BOOL)_onlyBinaries {
    [super dumpToDirectoryURL:directoryURL];

    [self prepareForDump];

    [[NSFileManager defaultManager] createDirectoryAtPath:_workingPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    ZipOperation *_mainZipOperation = [[ZipOperation alloc] initWithApplication:self];

    BundleDumpOperation *_dumpOperation = self.executable.dumpOperation;

    FinalizeDumpOperation *_finalizeDumpOperation = [[FinalizeDumpOperation alloc] initWithApplication:self];
    _finalizeDumpOperation.onlyBinaries = _onlyBinaries;

    if (!_onlyBinaries)
        [_finalizeDumpOperation addDependency:_mainZipOperation];

    [_finalizeDumpOperation addDependency:_dumpOperation];

    NSMutableArray *_additionalDumpOpeartions = ({
        NSMutableArray *array = [NSMutableArray new];

#ifdef DEBUG
        for (Application *_application in self.watchOSApps) {
            for (Extension *_extension in _application.extensions) {

                [array addObject:_extension.executable.dumpOperation];
            }
        }
#endif

        for (Framework *_framework in self.frameworks) {
            [array addObject:_framework.executable.dumpOperation];
        }

        for (Extension *_extension in self.extensions) {
            [array addObject:_extension.executable.dumpOperation];
        }
        array;
    });

    _finalizeDumpOperation.expectedBinariesCount = _additionalDumpOpeartions.count + 1;

    NSMutableArray *_additionalZipOpeartions = ({

        NSMutableArray *array = [NSMutableArray new];

#ifdef DEBUG
        for (Application *_application in self.watchOSApps) {
            for (Extension *_extension in _application.extensions) {
                ZipOperation *_zipOperation = [[ZipOperation alloc] initWithApplication:_extension];
                [_zipOperation addDependency:_mainZipOperation];

                [array addObject:_zipOperation];
            }
        }
#endif

        for (Framework *_framework in self.frameworks) {
            ZipOperation *_zipOperation = [[ZipOperation alloc] initWithApplication:_framework];
            [_zipOperation addDependency:_mainZipOperation];

            [array addObject:_zipOperation];
        }

        for (Extension *_extension in self.extensions) {
            ZipOperation *_zipOperation = [[ZipOperation alloc] initWithApplication:_extension];
            [_zipOperation addDependency:_mainZipOperation];

            [array addObject:_zipOperation];
        }
        array;
    });

    if (_onlyBinaries)
        [_additionalZipOpeartions removeAllObjects];

    for (unsigned int i = 1; i < _additionalZipOpeartions.count; i++) {
        ZipOperation *_zipOperation = _additionalZipOpeartions[i];
        [_zipOperation addDependency:_additionalZipOpeartions[i - 1]];
    }

    for (NSOperation *operation in _additionalDumpOpeartions) {
        [_finalizeDumpOperation addDependency:operation];
    }

    if (_additionalZipOpeartions.lastObject) {
        [_finalizeDumpOperation addDependency:_additionalZipOpeartions.lastObject];
    }

    if (!_onlyBinaries)
        [self.dumpQueue addOperation:_mainZipOperation];

    [self.dumpQueue addOperation:_dumpOperation];

    for (NSOperation *operation in _additionalDumpOpeartions) {
        [self.dumpQueue addOperation:operation];
    }

    for (NSOperation *operation in _additionalZipOpeartions) {
        [self.dumpQueue addOperation:operation];
    }

    [self.dumpQueue addOperation:_finalizeDumpOperation];
    BOOL failed = NO;

    while (self.dumpQueue.operationCount > 0) {
        for (NSOperation *op in self.dumpQueue.operations) {
            if ([op isKindOfClass:[BundleDumpOperation class]]) {
                BundleDumpOperation *op2 = (BundleDumpOperation *)op;
                if (op2.failed) {
                    failed = YES;
                    break;
                }
            }
        }
    }
    if (failed) {
        [self.dumpQueue cancelAllOperations];
    }

    [self.dumpQueue waitUntilAllOperationsAreFinished];

    return !failed;
}

- (NSString *)zipFilename {
    return [NSString stringWithFormat:@"%@-iOS%@-(Clutch-%@).ipa",
                                      self.bundleIdentifier,
                                      self.infoDictionary[@"MinimumOSVersion"],
                                      CLUTCH_VERSION];
}

- (NSString *)zipPrefix {
    return @"Payload";
}

- (NSURL *)enumURL {
    return self.bundleContainerURL;
}

- (NSArray *)frameworks {
    return _frameworks.copy;
}

- (NSArray *)extensions {
    return _extensions.copy;
}

- (NSString *)workingPath {
    return _workingPath;
}

@end
