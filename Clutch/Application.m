//
//  Application.m
//  Clutch
//
//  Created by Anton Titkov on 09.02.2015.
//
//

#import "Application.h"
#import "ZipOperation.h"
#import "BundleDumpOperation.h"
#import "FinalizeDumpOperation.h"
#import "SCInfoBuilder.h"
#import "Device.h"

@interface Application ()
{
    NSUUID *_workingUUID;
    NSMutableArray *_frameworks;
    NSMutableArray *_extensions;
    NSMutableArray *_watchOSApps;
    NSString *_workingPath;
}
@end

@implementation Application

- (instancetype)initWithBundleInfo:(NSDictionary *)info
{
    if (self = [super initWithBundleInfo:info]) {
        
        _workingUUID = [NSUUID new];
        _workingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"clutch" stringByAppendingPathComponent:_workingUUID.UUIDString]];
        
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
    if ([self.infoDictionary[@"CFBundleSupportedPlatforms"] containsObject:@"WatchOS"] || [self.infoDictionary[@"DTPlatformName"] isEqualToString:@"watchos"])
        return  YES;
    
    return NO;
}

- (void)reloadWatchOSAppsInfo
{
    _hasAppleWatchApp = NO;
    _watchOSApps = [NSMutableArray new];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL = [NSURL fileURLWithPath:[self.bundlePath stringByAppendingPathComponent:@"Watch"]]; // URL pointing to the directory you want to browse
    NSArray *keys = @[NSURLIsDirectoryKey];
    
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:^(NSURL *url, NSError *error) {
                                             // Handle the error.
                                             // Return YES if the enumeration should continue after the error.
                                             return YES;
                                         }];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        
        if (! [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // handle error
        }
        else if (![[url.path pathExtension] caseInsensitiveCompare:@"app"] && [isDirectory boolValue])
        {
            Application *watchOSApp = [[Application alloc]initWithBundleInfo:@{@"BundleContainer":url.URLByDeletingLastPathComponent,
                                                                     @"BundleURL":url}];
            
            if (watchOSApp.isAppleWatchApp) {
                _hasAppleWatchApp = YES;
                watchOSApp.parentBundle = self;
                [_watchOSApps addObject:watchOSApp];
            }

        }
    }
}

- (void)reloadFrameworksInfo
{
    _frameworks = [NSMutableArray new];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL = [NSURL fileURLWithPath:self.privateFrameworksPath]; // URL pointing to the directory you want to browse
    NSArray *keys = @[NSURLIsDirectoryKey];
    
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:^(NSURL *url, NSError *error) {
                                             // Handle the error.
                                             // Return YES if the enumeration should continue after the error.
                                             return YES;
                                         }];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        
        if (! [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // handle error
        }
        else if (![[url.path pathExtension] caseInsensitiveCompare:@"framework"] && [isDirectory boolValue])
        {
            Framework *fmwk = [[Framework alloc]initWithBundleInfo:@{@"BundleContainer":url.URLByDeletingLastPathComponent,
                                                                     @"BundleURL":url}];
            if (fmwk) {
                
                fmwk.parentBundle = self;
                
                [_frameworks addObject:fmwk];
            }
        }
    }
}

- (void)reloadPluginsInfo
{
    _extensions = [NSMutableArray new];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL = [NSURL fileURLWithPath:self.builtInPlugInsPath]; // URL pointing to the directory you want to browse
    NSArray *keys = @[NSURLIsDirectoryKey];
    
    NSDirectoryEnumerator *enumerator = [fileManager
                                         enumeratorAtURL:directoryURL
                                         includingPropertiesForKeys:keys
                                         options:0
                                         errorHandler:^(NSURL *url, NSError *error) {
                                             // Handle the error.
                                             // Return YES if the enumeration should continue after the error.
                                             return YES;
                                         }];
    
    for (NSURL *url in enumerator) {
        NSError *error;
        NSNumber *isDirectory = nil;
        
        if (! [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            // handle error
        }
        else if (![[url.path pathExtension] caseInsensitiveCompare:@"appex"] && [isDirectory boolValue])
        {
            Extension *_extension = [[Extension alloc]initWithBundleInfo:@{@"BundleContainer":url.URLByDeletingLastPathComponent,
                                                                           @"BundleURL":url}];
            if (_extension) {
                
                _extension.parentBundle = self;
                [_extensions addObject:_extension];
            }
        }
    }
}

- (void)dumpToDirectoryURL:(NSURL *)directoryURL onlyBinaries:(BOOL)yrn
{
    [super dumpToDirectoryURL:directoryURL];
    
    [self prepareForDump];
    
    //NSLog(@"SCInfo SINF for %@:\n %@",self,[SCInfoBuilder parseOriginaleSinfForBundle:self]);
    
    [[NSFileManager defaultManager]createDirectoryAtPath:_workingPath withIntermediateDirectories:YES attributes:nil error:nil];
        
    ZipOperation *_mainZipOperation = [[ZipOperation alloc]initWithApplication:self];
    
    BundleDumpOperation *_dumpOperation = self.executable.dumpOperation;
    
    FinalizeDumpOperation *_finalizeDumpOperation = [[FinalizeDumpOperation alloc]initWithApplication:self];
    _finalizeDumpOperation.onlyBinaries = yrn;
    
    if (!yrn)
      [_finalizeDumpOperation addDependency:_mainZipOperation];
    
    [_finalizeDumpOperation addDependency:_dumpOperation];
    
    NSMutableArray *_additionalDumpOpeartions = [NSMutableArray new];
    NSMutableArray *_additionalZipOpeartions = [NSMutableArray new];
    
#ifdef DEBUG
    for (Application *_application in self.watchOSApps) {
        for (Extension *_extension in _application.extensions) {
            ZipOperation *_zipOperation = [[ZipOperation alloc]initWithApplication:_extension];
            [_zipOperation addDependency:_mainZipOperation];
            
            [_additionalZipOpeartions addObject:_zipOperation];
            
            [_additionalDumpOpeartions addObject:_extension.executable.dumpOperation];
        }
    }
#endif
    
    for (Framework *_framework in self.frameworks) {
        ZipOperation *_zipOperation = [[ZipOperation alloc]initWithApplication:_framework];
        [_zipOperation addDependency:_mainZipOperation];
        
        [_additionalZipOpeartions addObject:_zipOperation];
        
        [_additionalDumpOpeartions addObject:_framework.executable.dumpOperation];
    }
    
    for (Extension *_extension in self.extensions) {
        ZipOperation *_zipOperation = [[ZipOperation alloc]initWithApplication:_extension];
        [_zipOperation addDependency:_mainZipOperation];
        
        [_additionalZipOpeartions addObject:_zipOperation];
        
        [_additionalDumpOpeartions addObject:_extension.executable.dumpOperation];
    }
    
    for (int i=1; i<_additionalZipOpeartions.count;i++) {
        ZipOperation *_zipOperation = _additionalZipOpeartions[i];

        if (!yrn)
            [_zipOperation addDependency:_additionalZipOpeartions[i-1]];
        
        BundleDumpOperation *_dumpOperation = _additionalDumpOpeartions[i];
        [_finalizeDumpOperation addDependency:_dumpOperation];
    }
    
    if (_additionalZipOpeartions.lastObject && !yrn) {
        [_finalizeDumpOperation addDependency:_additionalZipOpeartions.lastObject];
    }
    
    if (!yrn)
    [_dumpQueue addOperation:_mainZipOperation];
    
    [_dumpQueue addOperation:_dumpOperation];

    
    for (int i=0; i<_additionalZipOpeartions.count;i++) {
        ZipOperation *_zipOperation = _additionalZipOpeartions[i];
        
        if (!yrn)
        [_dumpQueue addOperation:_zipOperation];
        
        BundleDumpOperation *_dumpOperation = _additionalDumpOpeartions[i];
        [_dumpQueue addOperation:_dumpOperation];
    }
    
    _finalizeDumpOperation.expectedBinariesCount = _additionalDumpOpeartions.count + 1;
    
    [_dumpQueue addOperation:_finalizeDumpOperation];
}

- (NSString *)zipFilename
{
    return [NSString stringWithFormat:@"%@-iOS%@-(Clutch-%@).ipa",self.bundleIdentifier,self.infoDictionary[@"MinimumOSVersion"],CLUTCH_VERSION];
}

- (NSString *)zipPrefix
{
    return @"Payload";
}

- (NSURL *)enumURL
{
    return self.bundleContainerURL;
}

- (NSArray *)frameworks
{
    return _frameworks.copy;
}

- (NSArray *)extensions
{
    return _extensions.copy;
}

- (NSString *)workingPath
{
    return _workingPath;
}

@end
