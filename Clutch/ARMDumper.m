//
//  ARMDumper.m
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "ARMDumper.h"
#import <mach-o/fat.h>
#import "Device.h"
#import <dlfcn.h>
#import <mach/mach_traps.h>
#import <mach/mach_init.h>

@implementation ARMDumper

- (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM;
}


- (BOOL)dumpBinary {
    
    NSString *binaryDumpPath = [_originalBinary.workingPath stringByAppendingPathComponent:_originalBinary.binaryPath.lastPathComponent];
    
    NSFileHandle *newFileHandle = [[NSFileHandle alloc]initWithFileDescriptor:fileno(fopen(binaryDumpPath.UTF8String, "r+"))];
    
    NSString* swappedBinaryPath = _originalBinary.binaryPath, *newSinf = _originalBinary.sinfPath, *newSupp = _originalBinary.suppPath; // default values if we dont need to swap archs
    
    //check if cpusubtype matches
    if ((_thinHeader.header.cpusubtype != [Device cpu_subtype]) && _originalBinary.hasMultipleARMSlices) {
        //time to swap
        NSString* suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:_thinHeader]];
        
        swappedBinaryPath = [_originalBinary.binaryPath stringByAppendingString:suffix];
        newSinf = [_originalBinary.sinfPath stringByAppendingString:suffix];
        newSupp = [_originalBinary.supfPath stringByAppendingString:suffix];
        
        [[NSFileManager defaultManager] copyItemAtPath:_originalBinary.binaryPath toPath:swappedBinaryPath error:nil];
        [[NSFileManager defaultManager] copyItemAtPath:_originalBinary.sinfPath toPath:newSinf error:nil];
        [[NSFileManager defaultManager] copyItemAtPath:_originalBinary.suppPath toPath:newSupp error:nil];
        
        [self.originalFileHandle closeFile];
        self.originalFileHandle = [[NSFileHandle alloc]initWithFileDescriptor:fileno(fopen(swappedBinaryPath.UTF8String, "r+"))];
        
        uint32_t magic = [self.originalFileHandle intAtOffset:0];
        bool shouldSwap = magic == FAT_CIGAM;
#define SWAP(NUM) (shouldSwap ? CFSwapInt32(NUM) : NUM)
        
        NSData *buffer = [self.originalFileHandle readDataOfLength:4096];
        
        struct fat_header fat = *(struct fat_header *)buffer.bytes;
        fat.nfat_arch = SWAP(fat.nfat_arch);
        int offset = sizeof(struct fat_header);
        
        for (int i = 0; i < fat.nfat_arch; i++) {
            struct fat_arch arch;
            arch = *(struct fat_arch *)([buffer bytes] + offset);
            
            if ((SWAP(arch.cputype) == _thinHeader.header.cputype) && (SWAP(arch.cpusubtype) == _thinHeader.header.cpusubtype)) {
                
                thin_header macho = headerAtOffset(buffer, SWAP(arch.offset));
                
                arch.cputype = SWAP(CPU_TYPE_I386);
                arch.cpusubtype = SWAP(CPU_SUBTYPE_X86_ALL);
                
                [self.originalFileHandle replaceBytesInRange:NSMakeRange(offset, sizeof(struct fat_arch)) withBytes:&arch];
                
                macho.header.cputype = CPU_TYPE_I386;
                macho.header.cpusubtype = CPU_SUBTYPE_X86_ALL;
                
                [self.originalFileHandle replaceBytesInRange:NSMakeRange(macho.offset, sizeof(macho.header)) withBytes:&macho.header];
            }
            
            offset += sizeof(struct fat_arch);
        }
        
        NSLog(@"wrote new header to binary");
        
    }
    
    //actual dumping
    
    [newFileHandle seekToFileOffset:_thinHeader.offset + _thinHeader.size];
    
    struct linkedit_data_command ldid; // LC_CODE_SIGNATURE load header (for resign)
    struct encryption_info_command crypt; // LC_ENCRYPTION_INFO load header (for crypt*)
    struct segment_command __text; // __TEXT segment
    
    struct super_blob *codesignblob; // codesign blob pointer
    struct code_directory directory; // codesign directory index
    
    BOOL foundCrypt = NO, foundSignature = NO, foundStartText = NO;
    
    uint64_t __text_start = 0;
    
    gbprintln(@"32bit dumping: arch %@ offset %u", [Dumper readableArchFromHeader:_thinHeader], _thinHeader.offset);
    
    for (int i = 0; i < _thinHeader.header.ncmds; i++) {
        
        uint32_t cmd = [newFileHandle intAtOffset:newFileHandle.offsetInFile];
        uint32_t size = [newFileHandle intAtOffset:newFileHandle.offsetInFile+sizeof(uint32_t)];
        
        switch (cmd) {
            case LC_CODE_SIGNATURE: {
                [newFileHandle getBytes:&ldid inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct linkedit_data_command))];
                foundSignature = YES;
                
                NSLog(@"FOUND CODE SIGNATURE: dataoff %u | datasize %u",ldid.dataoff,ldid.datasize);
                
                break;
            }
            case LC_ENCRYPTION_INFO: {
                [newFileHandle getBytes:&crypt inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct encryption_info_command))];
                foundCrypt = YES;
                
                NSLog(@"FOUND ENCRYPTION INFO: cryptoff %u | cryptsize %u | cryptid %u",crypt.cryptoff,crypt.cryptsize,crypt.cryptid);
                
                break;
            }
            case LC_SEGMENT:
            {
                [newFileHandle getBytes:&__text inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct segment_command))];
                
                if (strncmp(__text.segname, "__TEXT", 6) == 0) {
                    foundStartText = YES;
                    NSLog(@"FOUND %s SEGMENT",__text.segname);
                    __text_start = __text.vmaddr;
                }
                break;
            }
        }
        
        [newFileHandle seekToFileOffset:newFileHandle.offsetInFile + size];
        
        if (foundCrypt && foundSignature && foundStartText)
            break;
    }
    
    // we need to have all of these
    if (!foundCrypt || !foundSignature || !foundStartText) {
        NSLog(@"dumping binary: some load commands were not found %@ %@ %@",foundCrypt?@"YES":@"NO",foundSignature?@"YES":@"NO",foundStartText?@"YES":@"NO");
        return NO;
    }
    
    NSLog(@"found all required load commands for %@ %@",_originalBinary,[Dumper readableArchFromHeader:_thinHeader]);
    
    pid_t pid; // store the process ID of the fork
    mach_port_t port; // mach port used for moving virtual memory
    kern_return_t err; // any kernel return codes
    int status; // status of the wait
    mach_vm_size_t local_size = 0; // amount of data moved into the buffer
    NSUInteger begin;
    
    // open handle to dylib loader
    void *handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    // load ptrace library into handle
    ptrace_ptr_t ptrace = dlsym(handle, "ptrace");
    
#warning todo posix_spawn support
    
    if ((pid = fork()) == 0) {
        ptrace(PT_TRACE_ME, 0, 0, 0); // trace
        execl(swappedBinaryPath.UTF8String, "", (char *) 0); // import binary memory into executable space
        printf("exit with err code 2 in case we could not import (this should not happen)\n");
        exit(2);
    } else if (pid < 0) {
        printf("error: Couldn't fork, did you compile with proper entitlements?\n");
        return NO; // couldn't fork
    }
    
    do {
        wait(&status);
        if (WIFEXITED( status ))
            return NO;
    } while (!WIFSTOPPED( status ));
    
    if ((err = task_for_pid(mach_task_self(), pid, &port) != KERN_SUCCESS)) {
        gbprintln(@"ERROR: Could not obtain mach port, did you sign with proper entitlements?");
        kill(pid, SIGKILL); // kill the fork
        return NO;
    }
    
    [newFileHandle seekToFileOffset:_thinHeader.offset + ldid.dataoff];
    
    codesignblob = malloc(ldid.datasize);
    
    [newFileHandle getBytes:codesignblob inRange:NSMakeRange(newFileHandle.offsetInFile, ldid.datasize)];
    
    uint64_t countBlobs = CFSwapInt32(codesignblob->count); // how many indexes?
    
    for (uint64_t index = 0; index < countBlobs; index++) {
        if (CFSwapInt32(codesignblob->index[index].type) == CSSLOT_CODEDIRECTORY) {
            begin = newFileHandle.offsetInFile + CFSwapInt32(codesignblob->index[index].offset);
            [newFileHandle seekToFileOffset:begin];
            [newFileHandle getBytes:&directory inRange:NSMakeRange(begin, sizeof(struct code_directory))];
            break;
        }
    }
    
    free(codesignblob);
    
    uint32_t pages = CFSwapInt32(directory.nCodeSlots); // get the amount of codeslots
    
    if (pages == 0) {
        kill(pid, SIGKILL); // kill the fork
        gbprintln(@"pages == 0");
        return FALSE;
    }
    
    void *checksum = malloc(pages * 20); // 160 bits for each hash (SHA1)
    uint8_t buf_d[0x1000]; // create a single page buffer
    uint8_t *buf = &buf_d[0]; // store the location of the buffer
    
    // we should only have to write and perform checksums on data that changes
    
    uint32_t togo = crypt.cryptsize + crypt.cryptoff;
    uint32_t pages_d = 0;
    BOOL header = TRUE;
    
    [newFileHandle seekToFileOffset:_thinHeader.offset];
    
    if ((_thinHeader.header.flags & MH_PIE) && !patchPIE)
    {
        mach_vm_address_t main_address;
        if(find_main_binary(pid, &main_address) != KERN_SUCCESS) {
            printf("Failed to find address of header!\n");
            return NO;
        }
        
        uint64_t aslr_slide;
        if(get_image_size(main_address, pid, &aslr_slide) == -1) {
            printf("Failed to find ASLR slide!\n");
            return NO;
        }
        
        printf("ASLR slide: 0x%llx\n", aslr_slide);
        __text_start = aslr_slide;
#warning should we __text_start += 0x2000? this method seems broken
        
    }
    
    if ((_thinHeader.header.flags & MH_PIE) && (!patchPIE)) {
        //VERBOSE("dumping binary: ASLR enabled, identifying dump location dynamically");
        // perform checks on vm regions
        memory_object_name_t object;
        vm_region_basic_info_data_64_t info;
        mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_64;
        mach_vm_address_t region_start = 0;
        mach_vm_size_t region_size = 0;
        vm_region_flavor_t flavor = VM_REGION_BASIC_INFO_64;
        err = 0;
        
        while (err == KERN_SUCCESS)
        {
            err = mach_vm_region(port, &region_start, &region_size, flavor, (vm_region_info_t) &info, &info_count, &object);
            NSLog(@"32-bit Region Size: %llu %u", region_size, crypt.cryptsize);
            
            if (region_size == crypt.cryptsize)
            {
                NSLog(@"region_size == cryptsize");
                break;
            }
            
            __text_start = region_start;
            region_start += region_size;
            region_size	= 0;
            
        }
        
        if (err != KERN_SUCCESS)
        {
            NSLog(@"mach_vm_error: %u", err);
            free(checksum);
            kill(pid, SIGKILL);
            printf("ASLR is enabled and we could not identify the decrypted memory region.\n");
            return FALSE;
            
        }
    }
    
    uint32_t headerProgress = sizeof(struct mach_header);
    uint32_t i_lcmd = 0;
    
    while (togo > 0) {
        // get a percentage for the progress bar
        
        if ((err = mach_vm_read_overwrite(port, (mach_vm_address_t) __text_start + (pages_d * 0x1000), (vm_size_t) 0x1000, (pointer_t) buf, &local_size)) != KERN_SUCCESS)	{
            
            printf("dumping binary: failed to dump a page (32)\n");
            if (__text_start == 0x4000 && (_thinHeader.header.flags & MH_PIE)) {
                printf("\n=================\n");
                printf("0x4000 binary detected, attempting to remove MH_PIE flag");
                printf("\n=================\n\n");
                free(checksum); // free checksum table
                kill(pid, SIGKILL); // kill the fork
                patchPIE = YES;
                return [self dumpBinary];
            }
            free(checksum); // free checksum table
            kill(pid, SIGKILL); // kill the fork
            
            return FALSE;
        }
        
        
        if (header) {
            // is this the first header page?
            if (i_lcmd == 0) {
                // is overdrive enabled?
                
            }
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
                } else if (l_cmd->cmd == LC_SEGMENT) {
                    //printf("lc segemn yo\n");
                    struct segment_command *newseg = (struct segment_command *) curloc;
                    if (newseg->fileoff == 0 && newseg->filesize > 0) {
                        // is overdrive enabled? this is __TEXT
                        
                    }
                }
                curloc += lcmd_size;
                if ((void *)curloc >= (void *)buf + 0x1000) {
                    //printf("skipped pass the haeder yo\n");
                    // we are currently extended past the header page
                    // offset for the next round:
                    headerProgress = (((void *)curloc - (void *)buf) % 0x1000);
                    // prevent attaching overdrive dylib by skipping
                    goto skipoverdrive;
                }
            }
            
            //overdrive shit there
            
            header = FALSE;
        }
    skipoverdrive:
        printf("attemtping to write to binary\n");
        //[binaryData replaceBytesInRange:NSMakeRange(binaryData.currentOffset, 0x1000) withBytes:buf length:0x1000];
        
        [newFileHandle writeData:[NSData dataWithBytes:buf length:0x1000]];
        
        [newFileHandle seekToFileOffset:newFileHandle.offsetInFile + 0x1000];
        
        sha1(checksum + (20 * pages_d), buf, 0x1000); // perform checksum on the page
        printf("doing checksum yo\n");
        togo -= 0x1000; // remove a page from the togo
        printf("togo yo %u\n", togo);
        pages_d += 1; // increase the amount of completed pages
    }
    
    return YES;
}

@end
