//
//  Dumper.m
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "Dumper.h"
#import "Device.h"

#import <spawn.h>

#ifndef _POSIX_SPAWN_DISABLE_ASLR
#define _POSIX_SPAWN_DISABLE_ASLR       0x0100
#endif

@implementation Dumper

- (instancetype)initWithHeader:(thin_header)macho originalBinary:(Binary *)binary {

    if (self = [super init]) {
        _thinHeader = macho;
        _originalBinary = binary;
        patchPIE = NO;
    }
    
    return self;
}

+ (NSString *)readableArchFromHeader:(thin_header)macho
{
    if (macho.header.cputype == CPU_TYPE_ARM64)
        return @"arm64";
    else if (macho.header.cpusubtype == CPU_SUBTYPE_ARM_V6)
        return @"armv6";
    else if (macho.header.cpusubtype == CPU_SUBTYPE_ARM_V7)
        return @"armv7";
    else if (macho.header.cpusubtype == CPU_SUBTYPE_ARM_V7S)
        return @"armv7s";
    
    return @"unknown";
}

static void
exit_with_errno (int err, const char *prefix)
{
    if (err)
    {
        fprintf (stderr,
                 "%s%s",
                 prefix ? prefix : "",
                 strerror(err));
        exit (err);
    }
}

- (pid_t)posix_spawn:(NSString *)binaryPath disableASLR:(BOOL)yrn
{
    pid_t pid = 0;
    
    const char *path = binaryPath.UTF8String;
    
    posix_spawnattr_t attr;
    
    exit_with_errno (posix_spawnattr_init (&attr), "::posix_spawnattr_init (&attr) error: ");
    
    // Here we are using a darwin specific feature that allows us to exec only
    // since we want this program to turn into the program we want to debug,
    // and also have the new program start suspended (right at __dyld_start)
    // so we can debug it
    short flags = POSIX_SPAWN_START_SUSPENDED | POSIX_SPAWN_SETEXEC;
    
    if (yrn)
    flags |= _POSIX_SPAWN_DISABLE_ASLR;
    
    // Set the flags we just made into our posix spawn attributes
    exit_with_errno (posix_spawnattr_setflags (&attr, flags), "::posix_spawnattr_setflags (&attr, flags) error: ");
    
    // I wish there was a posix_spawn flag to change the working directory of
    // the inferior process we will spawn, but there currently isn't. If there
    // ever is a better way to do this, we should use it. I would rather not
    // manually fork, chdir in the child process, and then posix_spawn with exec
    // as the whole reason for doing posix_spawn is to not hose anything up
    // after the fork and prior to the exec...
    //if (working_dir)
    //    chdir (working_dir);
    
    exit_with_errno (posix_spawn (&pid, path, NULL, &attr, NULL, NULL), "posix_spawn() error: ");
    
    posix_spawnattr_destroy (&attr);
    
    return pid;
}

- (cpu_type_t)supportedCPUType
{
#warning not implemented on purpose
    return NULL;
}

- (BOOL)dumpBinary
{
#warning not implemented on purpose
    return NO;
}

- (void)swapArch
{
    thin_header macho = _thinHeader;
    
    DumperLog(@"swapping archs");
    
    //time to swap
    NSString* suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:_thinHeader]];
    
    NSString *swappedBinaryPath = [_originalBinary.binaryPath stringByAppendingString:suffix];
    NSString *newSinf = [_originalBinary.sinfPath stringByAppendingString:suffix];
    NSString *newSupp = [_originalBinary.suppPath stringByAppendingString:suffix];
    
    NSString *newSupf = nil;

    if (macho.header.cputype == CPU_TYPE_ARM64) {
        newSupf = [_originalBinary.supfPath stringByAppendingString:suffix];
    }
    
    [[NSFileManager defaultManager] copyItemAtPath:_originalBinary.binaryPath toPath:swappedBinaryPath error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:_originalBinary.sinfPath toPath:newSinf error:nil];
    [[NSFileManager defaultManager] copyItemAtPath:_originalBinary.suppPath toPath:newSupp error:nil];
    if (newSupf) {
        [[NSFileManager defaultManager] copyItemAtPath:_originalBinary.supfPath toPath:newSupf error:nil];
    }
    
    [self.originalFileHandle closeFile];
    self.originalFileHandle = [[NSFileHandle alloc]initWithFileDescriptor:fileno(fopen(swappedBinaryPath.UTF8String, "r+"))];
    
    uint32_t magic = [self.originalFileHandle intAtOffset:0];
    bool shouldSwap = magic == FAT_CIGAM;
#define SWAP(NUM) (shouldSwap ? CFSwapInt32(NUM) : NUM)
    
    NSData *buffer = [self.originalFileHandle readDataOfLength:4096];
    
    struct fat_header fat = *(struct fat_header *)buffer.bytes;
    fat.nfat_arch = SWAP(fat.nfat_arch);
    int offset = sizeof(struct fat_header);
    int wOffset = offset;
    
    uint32_t nf = SWAP(1);
    [self.originalFileHandle replaceBytesInRange:NSMakeRange(sizeof(uint32_t), sizeof(uint32_t)) withBytes:&nf];
    
    for (int i = 0; i < fat.nfat_arch; i++) {
        struct fat_arch arch;
        arch = *(struct fat_arch *)([buffer bytes] + offset);
        
        if (!((SWAP(arch.cputype) == _thinHeader.header.cputype) && (SWAP(arch.cpusubtype) == _thinHeader.header.cpusubtype))) {
            [self.originalFileHandle replaceBytesInRange:NSMakeRange(wOffset, sizeof(struct fat_arch)) withBytes:&arch];
            wOffset += sizeof(struct fat_arch);
        }
        
        offset += sizeof(struct fat_arch);
    }
    
    char data[4096-wOffset];
    memset(data,'\0',sizeof(data));
    [self.originalFileHandle replaceBytesInRange:NSMakeRange(wOffset, 4096-wOffset) withBytes:&data];
    
    DumperLog(@"wrote new header to binary");

}

- (ArchCompatibility)compatibilityMode;
{
    cpu_type_t cputype = self.supportedCPUType;
    cpu_subtype_t cpusubtype = _thinHeader.header.cpusubtype;
    
    if ((cputype != _thinHeader.header.cputype) || (cpusubtype > Device.cpu_subtype) || (_thinHeader.header.cputype > Device.cpu_type)) {
        return ArchCompatibilityNotCompatible;
    }
    
    return ArchCompatibilityCompatible;

}

@end
