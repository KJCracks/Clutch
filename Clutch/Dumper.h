//
//  Dumper.h
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "BinaryDumpProtocol.h"
#import "GBPrint.h"
#import "Binary.h"
#import "ASLRDisabler.h"
#import "mach_vm.h"

@interface Dumper : NSObject
{
    Binary *_originalBinary;
    thin_header _thinHeader;
    BOOL patchPIE;
}

@property NSFileHandle *originalFileHandle;

+ (NSString *)readableArchFromHeader:(thin_header)macho;
- (pid_t)posix_spawn:(NSString *)binaryPath disableASLR:(BOOL)yrn;
- (instancetype)initWithHeader:(thin_header)macho originalBinary:(Binary *)binary NS_DESIGNATED_INITIALIZER;
- (ArchCompatibility)compatibilityMode;
@end
