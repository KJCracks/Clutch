//
//  NSBundle+Clutch.m
//  Clutch
//
//  Created by Anton Titkov on 20.04.15.
//
//
@import ObjectiveC.runtime;

#import "NSBundle+Clutch.h"

static NSString *_bID;

@implementation NSBundle (Clutch)

- (NSString *)clutchBID {
    return objc_getAssociatedObject(self, &_bID);
}

- (void)setClutchBID:(NSString *)clutchBID {
    [self willChangeValueForKey:@"clutchBID"];
    objc_setAssociatedObject(self, &_bID, clutchBID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self didChangeValueForKey:@"clutchBID"];
}

- (NSString *)bundleIdentifier {
    if ([self.bundlePath isEqualToString:NSBundle.mainBundle.bundlePath]) {
        return self.clutchBID;
    }

    return self.infoDictionary[(__bridge NSString *)kCFBundleIdentifierKey];
}

@end
