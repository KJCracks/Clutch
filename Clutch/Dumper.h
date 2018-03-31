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

NS_ASSUME_NONNULL_BEGIN

void *safe_trim(void *p, size_t n);
void exit_with_errno(int err, const char *prefix);
void _kill(pid_t pid);

@interface Dumper : NSObject <FrameworkBinaryDumpProtocol, BinaryDumpProtocol>

@property (nonatomic, readonly) BOOL isASLRProtected;
@property (nonatomic, retain) NSFileHandle *originalFileHandle;
@property (nonatomic, assign, readonly) BOOL shouldDisableASLR;
@property (nonatomic, retain) Binary *originalBinary;
@property (nonatomic, assign, readonly) thin_header thinHeader;
@property (nonatomic, readonly) ArchCompatibility compatibilityMode;

+ (NSString *)readableArchFromHeader:(thin_header)macho;
+ (NSString *)readableArchFromMachHeader:(struct mach_header)header;
- (pid_t)posix_spawn:(NSString *)binaryPath disableASLR:(BOOL)yrn;
- (pid_t)posix_spawn:(NSString *)binaryPath disableASLR:(BOOL)yrn suspend:(BOOL)suspend;
- (nullable instancetype)initWithHeader:(thin_header)macho
                         originalBinary:(nullable Binary *)binary NS_DESIGNATED_INITIALIZER;
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

NS_ASSUME_NONNULL_END
