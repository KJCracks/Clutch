//
//  Framework.m
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "Framework.h"
#import "Device.h"

@implementation Framework

- (instancetype)initWithBundleInfo:(NSDictionary *)info {
    if (self = [super initWithBundleInfo:info]) {
    }
    return self;
}

- (void)prepareForDump {
    [super prepareForDump];
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
