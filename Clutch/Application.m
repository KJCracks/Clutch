//
//  Application.m
//  Clutch
//
//  Created by Anton Titkov on 09.02.2015.
//
//

#import "Application.h"

@interface Application ()
{
    NSMutableArray *_frameworks;
    NSMutableArray *_extensions;
}
@end

@implementation Application

- (instancetype)initWithAppInfo:(NSDictionary *)info
{
    
    if (self = [super initWithAppInfo:info]) {
        
        _bundleContainerURL = [info[@"BundleContainer"] copy];
        
        // Application
        /*applicationContainer = info[@"ApplicationContainer"];
         applicationDisplayName = info[@"ApplicationDisplayName"];
         applicationName = info[@"ApplicationName"];
         appDirectory = info[@"ApplicationBasename"];
         realUniqueID = info[@"RealUniqueID"];
         applicationVersion = info[@"ApplicationVersion"];
         applicationBundleID = info[@"ApplicationBundleID"];
         applicationExecutableName = info[@"ApplicationExecutableName"];
         applicationSINF = info[@"ApplicationSINF"];
         minimumOSVersion = info[@"MinimumOSVersion"];
         
         // Extension
         if ([info[@"PlugIn"]  isEqual: @YES])
         {
         hasPlugin = YES;
         
         plugins = info[@"PlugIns"];
         }
         else
         {
         hasPlugin = NO;
         }
         
         if ([info[@"Framework"]  isEqual: @YES])
         {
         hasFramework = YES;
         frameworks = info[@"Frameworks"];
         }
         else
         {
         hasFramework = NO;
         }*/
        
        [self reloadFrameworksInfo];
        [self reloadPluginsInfo];        
    }
    return self;
}

- (void)reloadFrameworksInfo
{
    _frameworks = [NSMutableArray new];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *directoryURL = [NSURL fileURLWithPath:self.privateFrameworksPath]; // URL pointing to the directory you want to browse
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    
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
            Framework *fmwk = [Framework bundleWithURL:url];
            if (fmwk) {
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
    NSArray *keys = [NSArray arrayWithObject:NSURLIsDirectoryKey];
    
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
            Extension *fmwk = [Extension bundleWithURL:url];
            if (fmwk) {
                [_extensions addObject:fmwk];
            }
        }
    }
}

- (NSArray *)frameworks
{
    return _frameworks.copy;
}

- (NSArray *)extensions
{
    return _extensions.copy;
}

@end
