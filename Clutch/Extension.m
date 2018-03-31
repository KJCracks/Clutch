//
//  Extension.m
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "Extension.h"

@implementation Extension

- (instancetype)initWithBundleInfo:(NSDictionary *)info {
    if (self = [super initWithBundleInfo:info]) {
    }
    return self;
}

- (BOOL)isWatchKitExtension {
    return [self.infoDictionary[@"NSExtension"][@"NSExtensionPointIdentifier"] isEqualToString:@"com.apple.watchkit"];
}

- (NSString *)zipFilename {
    return self.parentBundle.zipFilename;
}

- (NSString *)zipPrefix {
    return
        [@"Payload" stringByAppendingPathComponent:[self.bundleContainerURL.path
                                                       stringByReplacingOccurrencesOfString:self.parentBundle
                                                                                                .bundleContainerURL.path
                                                                                 withString:@""]];
}

- (NSURL *)enumURL {
    return self.bundleURL;
}

- (NSString *)workingPath {
    return self.parentBundle.workingPath;
}

@end
