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
}

@property (readonly) BOOL isASLRProtected;
@property NSFileHandle *originalFileHandle;
@property BOOL shouldDisableASLR;

+ (NSString *)readableArchFromHeader:(thin_header)macho;
- (pid_t)posix_spawn:(NSString *)binaryPath disableASLR:(BOOL)yrn;
- (instancetype)initWithHeader:(thin_header)macho originalBinary:(Binary *)binary NS_DESIGNATED_INITIALIZER;
- (ArchCompatibility)compatibilityMode;

- (void)swapArch;
- (BOOL)_dumpToFileHandle:(NSFileHandle *)fileHandle withEncryptionInfoCommand:(uint32_t)crypt pages:(uint32_t)pages fromPort:(mach_port_t)port pid:(pid_t)pid aslrSlide:(mach_vm_address_t)aslrSlide;

@end

#define DumperLog(fmt,...) printf("\033[0;32mDumping: \044[0m %s\n",[NSString stringWithFormat:@"%@ " fmt, _originalBinary, ##__VA_ARGS__].UTF8String)

#ifdef DEBUG
#   define DumperDebugLog(fmt,...) NSLog(@"%@ " fmt,_originalBinary,##__VA_ARGS__)
#else
#   define DumperDebugLog(...)
#endif