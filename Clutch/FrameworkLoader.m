//
//  FrameworkLoader.m
//  Clutch
//
//  Created by Anton Titkov on 06.04.15.
//
//


#import "FrameworkLoader.h"
#import "Device.h"
#import <dlfcn.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <mach/mach_traps.h>
#import <mach/mach_init.h>
#import <mach-o/dyld_images.h>
#import "NSBundle+Clutch.h"
#import "progressbar.h"

@import ObjectiveC.runtime;

@interface FrameworkLoader ()
{
    uint32_t _dyldImageIndex;
}
@end

@implementation FrameworkLoader

- (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM | CPU_TYPE_ARM64;
}

- (BOOL)dumpBinary {
    
   
    
    NSString *binaryDumpPath = self.dumpPath;
    
    NSString* swappedBinaryPath = self.binPath; // default values if we dont need to swap archs
    
    NSDictionary *_infoPlist = [NSDictionary dictionaryWithContentsOfFile:[self.binPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"Info.plist"]];
    
    [NSBundle mainBundle].clutchBID = self.bID;//_infoPlist[@"CFBundleIdentifier"];
    
     _originalBinary = (Binary*)[NSString stringWithFormat:@"<%@>", _infoPlist[@"CFBundleExecutable"]];
    
    //DumperDebugLog(@"%@ %@",_infoPlist,[NSBundle mainBundle].bundleIdentifier);

    
    NSFileHandle *newFileHandle = [[NSFileHandle alloc]initWithFileDescriptor:fileno(fopen(binaryDumpPath.UTF8String, "r+"))];
        
    [newFileHandle seekToFileOffset:self.offset];
    
    void *handle = dlopen(swappedBinaryPath.UTF8String, RTLD_LAZY);
    
    if (!handle) {
        ERROR(@"Failed to dlopen %@ %s", swappedBinaryPath, dlerror());
        return NO;
    }
    
    uint32_t imageCount = _dyld_image_count();
    uint32_t dyldIndex = -1;
    for (uint32_t idx = 0; idx < imageCount; idx++) {
        NSString *dyldPath = [NSString stringWithUTF8String:_dyld_get_image_name(idx)];
        if ([swappedBinaryPath.lastPathComponent isEqualToString:dyldPath.lastPathComponent]) {
            dyldIndex = idx;
            break;
        }
    }
    
    if (dyldIndex == -1) {
        dlclose(handle);
        return NO;
    }
    
    _dyldImageIndex = dyldIndex;
    
    intptr_t dyldPointer = _dyld_get_image_vmaddr_slide(dyldIndex);
    
    DumperDebugLog(@"dyld offset %u", dyldPointer);
    
    BOOL dumpResult;
    
    //[self _dumpToFileHandle:newFileHandle withEncryptionInfoCommand:self.encryptionInfoCommand pages:self.pages fromPort:mach_task_self() pid:[NSProcessInfo processInfo].processIdentifier aslrSlide:dyldPointer];
    
    dumpResult = [self _dumpToFileHandle:newFileHandle withDumpSize:self.dumpSize pages:self.pages fromPort:mach_task_self() pid:[NSProcessInfo processInfo].processIdentifier aslrSlide:dyldPointer codeSignature_hashOffset:self.hashOffset codesign_begin:self.codesign_begin];
    
    dlclose(handle);
    
    return dumpResult;
}

- (BOOL)_dumpToFileHandle:(NSFileHandle *)fileHandle withDumpSize:(uint32_t)togo pages:(uint32_t)pages fromPort:(mach_port_t)port pid:(pid_t)pid aslrSlide:(mach_vm_address_t)__text_start codeSignature_hashOffset:(uint32_t)hashOffset codesign_begin:(uint32_t)begin
{
    
    DumperDebugLog(@"Using Framework Dumper, pages %u", pages);
    void *checksum = malloc(pages * 20); // 160 bits for each hash (SHA1)
    
    const struct mach_header *image_header = _dyld_get_image_header(_dyldImageIndex);
    
    SUCCESS(@"Dumping %@ %@", _originalBinary, [Dumper readableArchFromMachHeader:*image_header]);
    
    uint32_t headerProgress = sizeof(image_header);
    
    uint32_t i_lcmd = 0;
    kern_return_t err;
    uint32_t pages_d = 0;
    BOOL header = TRUE;
    
    uint8_t* buf = malloc(0x1000);
    mach_vm_size_t local_size = 0; // amount of data moved into the buffer

    [fileHandle seekToFileOffset:self.offset];

    unsigned long percent;
    //uint32_t total = togo;

    
    //progressbar* progress = progressbar_new([NSString stringWithFormat:@"\033[1;35mDumping %@ (%@)\033[0m", _originalBinary, [Dumper readableArchFromHeader:_thinHeader]].UTF8String, 100);
    
    while (togo > 0) {
        
        /*progress bars messes up console output
        percent = ceil((((double)total - togo) / (double)total) * 100);
        PROGRESS(progress, percent);*/

        memcpy(buf, (unsigned char*)image_header + (pages_d * 0x1000), 0x1000);
        [fileHandle writeData:[NSData dataWithBytes:buf length:0x1000]];
        sha1(checksum + (20 * pages_d), buf, 0x1000); // perform checksum on the page
        togo -= 0x1000; // remove a page from the togo
        pages_d += 1; // increase the amount of completed pages
    }
    free(buf);
    
    //nice! now let's write the new checksum data
    DumperDebugLog("Writing new checksum");

    [fileHandle seekToFileOffset:(begin + hashOffset)];
    
    NSData* trimmed_checksum = [[NSData dataWithBytes:checksum length:pages*20] subdataWithRange:NSMakeRange(0, 20*pages_d)];
    free(checksum);
    [fileHandle writeData:trimmed_checksum];
    
    DumperDebugLog(@"Done writing checksum");
    
    DumperDebugLog(@"Patching cryptid");
    
    NSData* data;
    
    if (image_header->cputype == CPU_TYPE_ARM64) {
        struct encryption_info_command_64 crypt;
        
        [fileHandle getBytes:&crypt atOffset:self.cryptlc_offset length:sizeof(struct encryption_info_command_64)];
        
        NSLog(@"current cryptid %u", crypt.cryptid);
        crypt.cryptid = 0;
        [fileHandle seekToFileOffset:self.cryptlc_offset];
        
        data = [NSData dataWithBytes:&crypt length:sizeof(struct encryption_info_command_64)];
        
    }
    else {
        struct encryption_info_command crypt;
        [fileHandle getBytes:&crypt atOffset:self.cryptlc_offset length:sizeof(struct encryption_info_command)];
        NSLog(@"current cryptid %u", crypt.cryptid);
        crypt.cryptid = 0;
        [fileHandle seekToFileOffset:self.cryptlc_offset];
        data = [NSData dataWithBytes:&crypt length:sizeof(struct encryption_info_command)];
    }
    
    [fileHandle writeData:data];
    return YES;
}


@end
