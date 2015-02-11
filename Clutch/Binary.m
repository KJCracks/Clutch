//
//  Binary.m
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "Binary.h"
#import "ClutchBundle.h"
@interface Binary ()
{
    ClutchBundle *_bundle;
    
	NSString* sinfPath;
	NSString* suppPath;
	NSString* supfPath;
}
@end

@implementation Binary

- (instancetype)init
{
    // foolproof
    return nil;
}

- (instancetype)initWithBundle:(ClutchBundle *)path
{
    if (self = [super init]) {
        _bundle = path;
    }
    
    return self;
}

- (NSString *)binaryPath
{
    return _bundle.executablePath;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, binary: %@>",NSStringFromClass([self class]),self,_bundle.executablePath.lastPathComponent];
}

@end


