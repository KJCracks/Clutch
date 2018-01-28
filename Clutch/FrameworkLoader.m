//
//  FrameworkLoader.m
//  Clutch
//
//  Created by Anton Titkov on 06.04.15.
//
//

#import "FrameworkLoader.h"
#import "ClutchPrint.h"
#import "Device.h"
#import "NSBundle+Clutch.h"
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/dyld_images.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import <mach/mach.h>
#import <mach/mach_init.h>
#import <mach/mach_traps.h>

@import ObjectiveC.runtime;

@interface FrameworkLoader () {
    uint32_t _dyldImageIndex;
}
@end

@implementation FrameworkLoader

- (cpu_type_t)supportedCPUType {
    return CPU_TYPE_ARM | CPU_TYPE_ARM64;
}

- (BOOL)dumpBinary {

    NSString *binaryDumpPath = self.dumpPath;

    NSString *swappedBinaryPath = self.binPath; // default values if we dont need to swap archs

    NSDictionary *_infoPlist =
        [NSDictionary dictionaryWithContentsOfFile:[self.binPath.stringByDeletingLastPathComponent
                                                       stringByAppendingPathComponent:@"Info.plist"]];

    [NSBundle mainBundle].clutchBID = self.bID; //_infoPlist[@"CFBundleIdentifier"];

    self.originalBinary = (Binary *)[NSString stringWithFormat:@"<%@>", _infoPlist[@"CFBundleExecutable"]];

    NSFileHandle *newFileHandle =
        [[NSFileHandle alloc] initWithFileDescriptor:fileno(fopen(binaryDumpPath.UTF8String, "r+"))];

    [newFileHandle seekToFileOffset:self.offset];

    void *handle = dlopen(swappedBinaryPath.UTF8String, RTLD_LAZY);

    if (!handle) {
        KJPrint(@"Failed to dlopen %@ %s", swappedBinaryPath, dlerror());
        return NO;
    }

    uint32_t imageCount = _dyld_image_count();
    uint32_t dyldIndex = 0;
    BOOL modifiedDyldIndex = NO;
    for (uint32_t idx = 0; idx < imageCount; idx++) {
        NSString *dyldPath = @(_dyld_get_image_name(idx));
        if ([swappedBinaryPath.lastPathComponent isEqualToString:dyldPath.lastPathComponent]) {
            dyldIndex = idx;
            modifiedDyldIndex = YES;
            break;
        }
    }

    if (!modifiedDyldIndex) {
        dlclose(handle);
        return NO;
    }

    _dyldImageIndex = dyldIndex;

    intptr_t dyldPointer = _dyld_get_image_vmaddr_slide(dyldIndex);

    KJDebug(@"dyld offset %u", dyldPointer);

    BOOL dumpResult;

    //[self _dumpToFileHandle:newFileHandle withEncryptionInfoCommand:self.encryptionInfoCommand pages:self.pages
    // fromPort:mach_task_self() pid:[NSProcessInfo processInfo].processIdentifier aslrSlide:dyldPointer];

    dumpResult = [self _dumpToFileHandle:newFileHandle
                            withDumpSize:self.dumpSize
                                   pages:self.pages
                                fromPort:mach_task_self()
                                     pid:[NSProcessInfo processInfo].processIdentifier
                               aslrSlide:(mach_vm_address_t)dyldPointer
                codeSignature_hashOffset:self.hashOffset
                          codesign_begin:self.codesign_begin];

    dlclose(handle);

    return dumpResult;
}

- (BOOL)_dumpToFileHandle:(NSFileHandle *)fileHandle
                withDumpSize:(uint32_t)togo
                       pages:(uint32_t)pages
                    fromPort:(mach_port_t)port
                         pid:(pid_t)pid
                   aslrSlide:(mach_vm_address_t)__text_start
    codeSignature_hashOffset:(uint32_t)hashOffset
              codesign_begin:(uint32_t)begin {
    CLUTCH_UNUSED(port);
    CLUTCH_UNUSED(pid);
    CLUTCH_UNUSED(__text_start);

    KJDebug(@"Using Framework Dumper, pages %u", pages);
    void *checksum = malloc(pages * 20); // 160 bits for each hash (SHA1)

    const struct mach_header *image_header = _dyld_get_image_header(_dyldImageIndex);

    KJPrint(@"Dumping %@ %@", self.originalBinary, [Dumper readableArchFromMachHeader:*image_header]);

    uint32_t pages_d = 0;

    uint8_t *buf = malloc(0x1000);

    [fileHandle seekToFileOffset:self.offset];

    while (togo > 0) {
        memcpy(buf, (unsigned char *)image_header + (pages_d * 0x1000), 0x1000);
        [fileHandle writeData:[NSData dataWithBytes:buf length:0x1000]];
        // https://gcc.gnu.org/onlinedocs/gcc/Pointer-Arith.html
        sha1((uint8_t *)checksum + (20 * pages_d), buf, 0x1000); // perform checksum on the page
        togo -= 0x1000;                                          // remove a page from the togo
        pages_d += 1;                                            // increase the amount of completed pages
    }
    free(buf);

    // nice! now let's write the new checksum data
    KJDebug(@"Writing new checksum");

    [fileHandle seekToFileOffset:(begin + hashOffset)];

    NSData *trimmed_checksum =
        [[NSData dataWithBytes:checksum length:pages * 20] subdataWithRange:NSMakeRange(0, 20 * pages_d)];
    free(checksum);
    [fileHandle writeData:trimmed_checksum];

    KJDebug(@"Done writing checksum");

    KJDebug(@"Patching cryptid");

    NSData *data;

    if (image_header->cputype == CPU_TYPE_ARM64) {
        struct encryption_info_command_64 crypt;

        [fileHandle getBytes:&crypt atOffset:self.cryptlc_offset length:sizeof(struct encryption_info_command_64)];

        KJDebug(@"current cryptid %u", crypt.cryptid);
        crypt.cryptid = 0;
        [fileHandle seekToFileOffset:self.cryptlc_offset];

        data = [NSData dataWithBytes:&crypt length:sizeof(struct encryption_info_command_64)];

    } else {
        struct encryption_info_command crypt;
        [fileHandle getBytes:&crypt atOffset:self.cryptlc_offset length:sizeof(struct encryption_info_command)];
        KJDebug(@"current cryptid %u", crypt.cryptid);
        crypt.cryptid = 0;
        [fileHandle seekToFileOffset:self.cryptlc_offset];
        data = [NSData dataWithBytes:&crypt length:sizeof(struct encryption_info_command)];
    }

    [fileHandle writeData:data];
    return YES;
}

@end
