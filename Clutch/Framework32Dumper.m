//
//  Framework32Dumper.m
//  Clutch
//
//  Created by Anton Titkov on 06.04.15.
//
//

#import "Framework32Dumper.h"
#import "Device.h"
#import <dlfcn.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <mach/mach_traps.h>
#import <mach/mach_init.h>
#import <mach-o/dyld_images.h>

@implementation Framework32Dumper

- (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM;
}

- (BOOL)dumpBinary {
    
    NSString *binaryDumpPath = self.dumpPath;
    
    NSString* swappedBinaryPath = self.binPath; // default values if we dont need to swap archs
    
    NSFileHandle *newFileHandle = [[NSFileHandle alloc]initWithFileDescriptor:fileno(fopen(binaryDumpPath.UTF8String, "r+"))];
        
    [newFileHandle seekToFileOffset:self.offset];
    
    void * handle = dlopen(swappedBinaryPath.UTF8String, RTLD_LAZY);
    
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
    
    intptr_t dyldPointer = _dyld_get_image_vmaddr_slide(dyldIndex);
    
    BOOL dumpResult = [self _dumpToFileHandle:newFileHandle withEncryptionInfoCommand:self.encryptionInfoCommand pages:self.pages fromPort:mach_task_self() pid:[NSProcessInfo processInfo].processIdentifier aslrSlide:dyldPointer];
    
    dlclose(handle);
    
    return dumpResult;
}

- (BOOL)_dumpToFileHandle:(NSFileHandle *)fileHandle withEncryptionInfoCommand:(uint32_t)togo pages:(uint32_t)pages fromPort:(mach_port_t)port pid:(pid_t)pid aslrSlide:(mach_vm_address_t)__text_start
{
    void *checksum = malloc(pages * 20); // 160 bits for each hash (SHA1)
    
    
    uint32_t headerProgress = sizeof(struct mach_header);
    
    uint32_t i_lcmd = 0;
    kern_return_t err;
    uint32_t pages_d = 0;
    BOOL header = TRUE;
    
    uint8_t buf_d[0x1000]; // create a single page buffer
    uint8_t *buf = &buf_d[0]; // store the location of the buffer
    mach_vm_size_t local_size = 0; // amount of data moved into the buffer
    
    while (togo > 0) {
        // get a percentage for the progress bar
        
        if ((err = mach_vm_read_overwrite(port, (mach_vm_address_t) __text_start + (pages_d * 0x1000), (vm_size_t) 0x1000, (pointer_t) buf, &local_size)) != KERN_SUCCESS)
            return NO;
        
        if (header) {
            
            // iterate over the header (or resume iteration)
            void *curloc = buf + headerProgress;
            for (;i_lcmd<self.ncmds;i_lcmd++) {
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


@end
