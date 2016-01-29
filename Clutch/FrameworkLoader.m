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
    
    uint32_t headerProgress = sizeof(image_header);
    
    uint32_t i_lcmd = 0;
    kern_return_t err;
    int pages_d = 0;
    BOOL header = TRUE;
    
    uint8_t* buf = malloc(0x1000);
    mach_vm_size_t local_size = 0; // amount of data moved into the buffer
    
    void* decrypted = malloc(self.cryptsize);
    memcpy(decrypted, (unsigned char*)image_header + self.cryptoff, self.cryptsize);
    
    [fileHandle seekToFileOffset:self.offset + self.cryptoff];
    [fileHandle writeData:[NSData dataWithBytes:decrypted length:self.cryptsize]];

    NSData* data;
    
    if (image_header->cputype == CPU_TYPE_ARM64) {
        struct encryption_info_command_64 crypt;
        
        [fileHandle getBytes:&crypt atOffset:self.cryptlc_offset length:sizeof(struct encryption_info_command_64)];
        
        NSLog(@"current cryptid %u", crypt.cryptid);
        crypt.cryptid = 0;
        [fileHandle seekToFileOffset:self.cryptlc_offset];

        data = [NSData dataWithBytes:&crypt length:sizeof(struct encryption_info_command_64)];
        [fileHandle writeData:data];
    }
    else {
        struct encryption_info_command crypt;
         [fileHandle getBytes:&crypt atOffset:self.cryptlc_offset length:sizeof(struct encryption_info_command)];
        NSLog(@"current cryptid %u", crypt.cryptid);
        crypt.cryptid = 0;
        [fileHandle seekToFileOffset:self.cryptlc_offset];
        data = [NSData dataWithBytes:&crypt length:sizeof(struct encryption_info_command)];
        [fileHandle writeData:data];
    }
    
    [fileHandle seekToFileOffset:self.offset];

    DumperLog(@"Finished patching cryptid (Framework)");
    while (togo > 0) {
        data = [fileHandle readDataOfLength:0x1000];
        [data getBytes:buf length:0x1000];
        //NSLog(@"reading page %u", CFSwapInt32(pages_d));
        sha1(checksum + (20 * pages_d), buf, 0x1000); // perform checksum on the page
        //NSLog(@"checksum ok");
        togo -= 0x1000; // remove a page from the togo
        pages_d += 1; // increase the amount of completed pages
    }
    //nice! now let's write the new checksum data
    DumperLog("Writing new checksum");
    [fileHandle seekToFileOffset:(begin + hashOffset)];
    
    
    int length = (20*pages_d);
    void* trimmed_checksum = safe_trim(checksum, length);
    
    data = [NSMutableData dataWithBytes:trimmed_checksum length:length];
    
    [fileHandle writeData:data];
    
    DumperLog(@"Done writing checksum");
    return YES;
}


@end
