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

void *safe_trim(void *p, size_t n);

@interface Dumper : NSObject
{
    Binary *_originalBinary;
    thin_header _thinHeader;
}
void exit_with_errno (int err, const char *prefix);

@property (readonly) BOOL isASLRProtected;
@property NSFileHandle *originalFileHandle;
@property BOOL shouldDisableASLR;

+ (NSString *)readableArchFromHeader:(thin_header)macho;
+ (NSString *)readableArchFromMachHeader:(struct mach_header)header;
- (pid_t)posix_spawn:(NSString *)binaryPath disableASLR:(BOOL)yrn;
- (pid_t)posix_spawn:(NSString *)binaryPath disableASLR:(BOOL)yrn suspend:(BOOL) suspend;
- (instancetype)initWithHeader:(thin_header)macho originalBinary:(Binary *)binary NS_DESIGNATED_INITIALIZER;
- (ArchCompatibility)compatibilityMode;

- (void)swapArch;

- (BOOL)_dumpToFileHandle:(NSFileHandle *)fileHandle withDumpSize:(uint32_t)togo pages:(uint32_t)pages fromPort:(mach_port_t)port pid:(pid_t)pid aslrSlide:(mach_vm_address_t)__text_start codeSignature_hashOffset:(uint32_t)hashOffset codesign_begin:(uint32_t)begin;

@end

#define DumperLog(fmt,...) fprintf(stderr, "\033[0;34mDUMP |\033[0m %s\n",[NSString stringWithFormat:@"%@ <%@> %@ " fmt, NSStringFromClass([self class]), [Dumper readableArchFromHeader:_thinHeader], _originalBinary, ##__VA_ARGS__].UTF8String)

#ifdef DEBUG
#   define PROGRESS(progress, percent)
#   define DumperDebugLog(fmt,...) NSLog(@"DUMP: %@ %@ %@ " fmt, self, [Dumper readableArchFromHeader:_thinHeader], _originalBinary,##__VA_ARGS__)
#else
#   define DumperDebugLog(...)
#   define PROGRESS(progress, percent) progressbar_update(progress, percent);
#endif