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
#import "ClutchBundle.h"
#import "ClutchPrint.h"

void *safe_trim(void *p, size_t n);

@interface Dumper : NSObject
{
    Binary *_originalBinary;
    thin_header _thinHeader;
}
void exit_with_errno (int err, const char *prefix);
void _kill(pid_t pid);

@property (readonly) BOOL isASLRProtected;
@property NSFileHandle *originalFileHandle;
@property BOOL shouldDisableASLR;


+ (NSString *)readableArchFromHeader:(thin_header)macho;
+ (NSString *)readableArchFromMachHeader:(struct mach_header)header;
- (pid_t)posix_spawn:(NSString *)binaryPath disableASLR:(BOOL)yrn;
- (pid_t)posix_spawn:(NSString *)binaryPath disableASLR:(BOOL)yrn suspend:(BOOL) suspend;
- (instancetype)initWithHeader:(thin_header)macho originalBinary:(Binary *)binary;
- (ArchCompatibility)compatibilityMode;

- (void)swapArch;

- (BOOL)_dumpToFileHandle:(NSFileHandle *)fileHandle withDumpSize:(uint32_t)togo pages:(uint32_t)pages fromPort:(mach_port_t)port pid:(pid_t)pid aslrSlide:(mach_vm_address_t)__text_start codeSignature_hashOffset:(uint32_t)hashOffset codesign_begin:(uint32_t)begin;

@end