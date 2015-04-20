//
//  NSBundle+Clutch.m
//  Clutch
//
//  Created by Anton Titkov on 20.04.15.
//
//

#import "NSBundle+Clutch.h"

@import ObjectiveC.runtime;

@implementation NSBundle (Clutch)

static NSString* _bID;

- (NSString *)clutchBID
{
    NSString *value = objc_getAssociatedObject(self, &_bID);
    return value;
}

- (void)setClutchBID:(NSString *)clutchBID
{
    [self willChangeValueForKey:@"clutchBID"];
    objc_setAssociatedObject(self, &_bID, clutchBID, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self didChangeValueForKey:@"clutchBID"];
}

- (NSString *)bundleIdentifier {
    
    if ([self.bundlePath isEqualToString:[NSBundle mainBundle].bundlePath]) {
        
        return self.clutchBID;
    }
    
    return self.infoDictionary[@"CFBundleIdentifier"];
}

@end
