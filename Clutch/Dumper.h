//
//  Dumper.h
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "ASLRDisabler.h"
#import "Binary.h"
#import "BinaryDumpProtocol.h"
#import "ClutchBundle.h"
#import "ClutchPrint.h"
#import "mach_vm.h"

void *safe_trim(void *p, size_t n);
void exit_with_errno(int err, const char *prefix);
void _kill(pid_t pid);

@interface Dumper : NSObject

@property (nonatomic, readonly) BOOL isASLRProtected;
@property (nonatomic, retain) NSFileHandle *originalFileHandle;
@property (nonatomic, assign) BOOL shouldDisableASLR;
@property (nonatomic, retain) Binary *originalBinary;
@property (nonatomic, assign) thin_header thinHeader;

+ (NSString *)readableArchFromHeader:(thin_header)macho;
+ (NSString *)readableArchFromMachHeader:(struct mach_header)header;
- (pid_t)posix_spawn:(NSString *)binaryPath disableASLR:(BOOL)yrn;
- (pid_t)posix_spawn:(NSString *)binaryPath disableASLR:(BOOL)yrn suspend:(BOOL)suspend;
- (instancetype)initWithHeader:(thin_header)macho originalBinary:(Binary *)binary;
- (ArchCompatibility)compatibilityMode;
- (void)swapArch;
- (BOOL)_dumpToFileHandle:(NSFileHandle *)fileHandle
                withDumpSize:(uint32_t)togo
                       pages:(uint32_t)pages
                    fromPort:(mach_port_t)port
                         pid:(pid_t)pid
                   aslrSlide:(mach_vm_address_t)__text_start
    codeSignature_hashOffset:(uint32_t)hashOffset
              codesign_begin:(uint32_t)begin;

@end
