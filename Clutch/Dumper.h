//
//  Dumper.h
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "BinaryDumpProtocol.h"

#import "Binary.h"

@interface Dumper : NSObject
{
    Binary *_originalBinary;
    thin_header _thinHeader;
}

+ (NSString *)readableArchFromHeader:(thin_header)macho;
- (pid_t)posix_spawn;
- (instancetype)initWithHeader:(thin_header)macho originalBinary:(Binary *)binary NS_DESIGNATED_INITIALIZER;
- (ArchCompatibility)compatibilityMode;
@end
