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
        _shouldDisableASLR = NO;
        
        _isASLRProtected = (_thinHeader.header.flags & MH_PIE);
        
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
    
    if ((_thinHeader.header.flags & MH_PIE) && yrn) {
        
        DumperLog(@"disabling MH_PIE!!!!");
        
        _thinHeader.header.flags &= ~MH_PIE;
        [self.originalFileHandle replaceBytesInRange:NSMakeRange(_thinHeader.offset, sizeof(_thinHeader.header)) withBytes:&_thinHeader.header];
    }else if (_isASLRProtected && !yrn && !(_thinHeader.header.flags & MH_PIE)) {
        
        DumperLog(@"enabling MH_PIE!!!!");
        
        _thinHeader.header.flags |= MH_PIE;
        [self.originalFileHandle replaceBytesInRange:NSMakeRange(_thinHeader.offset, sizeof(_thinHeader.header)) withBytes:&_thinHeader.header];
    }else {
        DumperLog(@"to MH_PIE or not to MH_PIE, that is the question");
    }
    
    pid_t pid = 0;
    
    const char *path = binaryPath.UTF8String;
    
    posix_spawnattr_t attr;
    
    exit_with_errno (posix_spawnattr_init (&attr), "::posix_spawnattr_init (&attr) error: ");
    
    short flags = POSIX_SPAWN_START_SUSPENDED;
    
    if (yrn)
        flags |= _POSIX_SPAWN_DISABLE_ASLR;
    
    // Set the flags we just made into our posix spawn attributes
    exit_with_errno (posix_spawnattr_setflags (&attr, flags), "::posix_spawnattr_setflags (&attr, flags) error: ");
    
    posix_spawnp (&pid, path, NULL, &attr, NULL, NULL);
    
    posix_spawnattr_destroy (&attr);
    
    return pid;
}

- (cpu_type_t)supportedCPUType
{
    return NULL;
}

- (BOOL)dumpBinary
{
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

- (BOOL)_dumpToFileHandle:(NSFileHandle *)fileHandle withEncryptionInfoCommand:(uint32_t)togo pages:(uint32_t)pages fromPort:(mach_port_t)port pid:(pid_t)pid aslrSlide:(mach_vm_address_t)__text_start
{
    void *checksum = malloc(pages * 20); // 160 bits for each hash (SHA1)
    
    
    uint32_t headerProgress = _thinHeader.header.cputype == CPU_TYPE_ARM64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header);
    
    uint32_t i_lcmd = 0;
    kern_return_t err;
    uint32_t pages_d = 0;
    BOOL header = TRUE;
    
    uint8_t buf_d[0x1000]; // create a single page buffer
    uint8_t *buf = &buf_d[0]; // store the location of the buffer
    mach_vm_size_t local_size = 0; // amount of data moved into the buffer
    
    
    while (togo > 0) {
        // get a percentage for the progress bar
        
        if ((err = mach_vm_read_overwrite(port, (mach_vm_address_t) __text_start + (pages_d * 0x1000), (vm_size_t) 0x1000, (pointer_t) buf, &local_size)) != KERN_SUCCESS)	{
            
            DumperLog(@"dumping binary: failed to dump a page (32)");
            if (__text_start == 0x4000 && (_thinHeader.header.flags & MH_PIE)) {
                DumperLog(@"\n=================");
                DumperLog(@"0x4000 binary detected, attempting to remove MH_PIE flag");
                DumperLog(@"\n=================\n");
                free(checksum); // free checksum table
                kill(pid, SIGKILL); // kill the fork
                _shouldDisableASLR = YES;
                return [self dumpBinary];
            }
            free(checksum); // free checksum table
            kill(pid, SIGKILL); // kill the fork
            
            return NO;
        }
        
        
        if (header) {
            
            // iterate over the header (or resume iteration)
            void *curloc = buf + headerProgress;
            for (;i_lcmd<_thinHeader.header.ncmds;i_lcmd++) {
                struct load_command *l_cmd = (struct load_command *) curloc;
                // is the load command size in a different page?
                uint32_t lcmd_size;
                if ((int)(((void*)curloc - (void*)buf) + 4) == 0x1000) {
                    // load command size is at the start of the next page
                    // we need to get it
                    //vm_read_overwrite(port, (mach_vm_address_t) __text_start + ((pages_d+1) * 0x1000), (vm_size_t) 0x1, (pointer_t) &lcmd_size, &local_size);
                    mach_vm_read_overwrite(port, (mach_vm_address_t) __text_start + ((pages_d + 1) * 0x1000), (vm_size_t) 0x1, (mach_vm_address_t) &lcmd_size, &local_size);
                    //printf("ieterating through header\n");
                } else {
                    lcmd_size = l_cmd->cmdsize;
                }
                
                if (l_cmd->cmd == LC_ENCRYPTION_INFO) {
                    struct encryption_info_command *newcrypt = (struct encryption_info_command *) curloc;
                    newcrypt->cryptid = 0; // change the cryptid to 0
                    //VERBOSE("dumping binary: patched cryptid");
                } else if (l_cmd->cmd == LC_ENCRYPTION_INFO_64) {
                    struct encryption_info_command_64 *newcrypt = (struct encryption_info_command_64 *) curloc;
                    newcrypt->cryptid = 0; // change the cryptid to 0
                    //VERBOSE("dumping binary: patched cryptid");
                }
                
                curloc += lcmd_size;
                if ((void *)curloc >= (void *)buf + 0x1000) {
                    //printf("skipped pass the haeder yo\n");
                    // we are currently extended past the header page
                    // offset for the next round:
                    headerProgress = (((void *)curloc - (void *)buf) % 0x1000);
                    // prevent attaching overdrive dylib by skipping
                    goto writedata;
                }
            }
            
            header = FALSE;
        }
        
    writedata:
        [fileHandle writeData:[NSData dataWithBytes:buf length:0x1000]];
        
        sha1(checksum + (20 * pages_d), buf, 0x1000); // perform checksum on the page
        togo -= 0x1000; // remove a page from the togo
        pages_d += 1; // increase the amount of completed pages
    }
    
    return YES;
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
