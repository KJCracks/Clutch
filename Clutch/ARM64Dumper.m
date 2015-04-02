//
//  ARM64Dumper.m
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "ARM64Dumper.h"
#import <mach-o/fat.h>
#import "Device.h"
#import <dlfcn.h>
#import <mach/mach_traps.h>
#import <mach/mach_init.h>

@implementation ARM64Dumper

- (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM64;
}

- (BOOL)dumpBinary {
    
    NSString *binaryDumpPath = [_originalBinary.workingPath stringByAppendingPathComponent:_originalBinary.binaryPath.lastPathComponent];
    
    NSFileHandle *newFileHandle = [[NSFileHandle alloc]initWithFileDescriptor:fileno(fopen(binaryDumpPath.UTF8String, "r+"))];
    
    NSString* swappedBinaryPath = _originalBinary.binaryPath, *newSinf = _originalBinary.sinfPath, *newSupp = _originalBinary.suppPath, *newSupf = _originalBinary.supfPath; // default values if we dont need to swap archs
    
    //check if cpusubtype matches
    if ((_thinHeader.header.cpusubtype != [Device cpu_subtype]) && _originalBinary.hasMultipleARM64Slices) {
    
        NSString* suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:_thinHeader]];
        
        swappedBinaryPath = [_originalBinary.binaryPath stringByAppendingString:suffix];
        newSinf = [_originalBinary.sinfPath stringByAppendingString:suffix];
        newSupp = [_originalBinary.suppPath stringByAppendingString:suffix];
        newSupf = [_originalBinary.supfPath stringByAppendingString:suffix];

        [self swapArch];
    }
    
    //actual dumping
    
    [newFileHandle seekToFileOffset:_thinHeader.offset + _thinHeader.size];
    
    struct linkedit_data_command ldid; // LC_CODE_SIGNATURE load header (for resign)
    struct encryption_info_command_64 crypt; // LC_ENCRYPTION_INFO load header (for crypt*)
    struct segment_command_64 __text; // __TEXT segment
    
    struct super_blob *codesignblob; // codesign blob pointer
    struct code_directory directory; // codesign directory index
    
    BOOL foundCrypt = NO, foundSignature = NO, foundStartText = NO;
    
    uint64_t __text_start = 0;
    
    DumperLog(@"64bit dumping: arch %@ offset %u", [Dumper readableArchFromHeader:_thinHeader], _thinHeader.offset);
    
    for (int i = 0; i < _thinHeader.header.ncmds; i++) {
        
        uint32_t cmd = [newFileHandle intAtOffset:newFileHandle.offsetInFile];
        uint32_t size = [newFileHandle intAtOffset:newFileHandle.offsetInFile+sizeof(uint32_t)];
        
        switch (cmd) {
            case LC_CODE_SIGNATURE: {
                [newFileHandle getBytes:&ldid inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct linkedit_data_command))];
                foundSignature = YES;
                
                DumperDebugLog(@"FOUND CODE SIGNATURE: dataoff %u | datasize %u",ldid.dataoff,ldid.datasize);
                
                break;
            }
            case LC_ENCRYPTION_INFO_64: {
                [newFileHandle getBytes:&crypt inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct encryption_info_command_64))];
                foundCrypt = YES;
                
                DumperDebugLog(@"FOUND ENCRYPTION INFO: cryptoff %u | cryptsize %u | cryptid %u",crypt.cryptoff,crypt.cryptsize,crypt.cryptid);
                
                break;
            }
            case LC_SEGMENT_64:
            {
                [newFileHandle getBytes:&__text inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct segment_command_64))];
                
                if (strncmp(__text.segname, "__TEXT", 6) == 0) {
                    foundStartText = YES;
                    DumperDebugLog(@"FOUND %s SEGMENT",__text.segname);
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
        DumperDebugLog(@"dumping binary: some load commands were not found %@ %@ %@",foundCrypt?@"YES":@"NO",foundSignature?@"YES":@"NO",foundStartText?@"YES":@"NO");
        return NO;
    }
    
    DumperDebugLog(@"found all required load commands for %@ %@",_originalBinary,[Dumper readableArchFromHeader:_thinHeader]);
    
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
        DumperLog(@"exit with err code 2 in case we could not import (this should not happen)");
        exit(2);
    } else if (pid < 0) {
        DumperLog(@"error: Couldn't fork, did you compile with proper entitlements?");
        return NO; // couldn't fork
    }
    
    do {
        wait(&status);
        if (WIFEXITED( status ))
        {
            DumperLog(@"ERROR: WIFEXITED(status)");
            return NO;
        }
    } while (!WIFSTOPPED( status ));
    
    if ((err = task_for_pid(mach_task_self(), pid, &port) != KERN_SUCCESS)) {
        DumperLog(@"ERROR: Could not obtain mach port, did you sign with proper entitlements?");
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
        DumperLog(@"pages == 0");
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
            DumperLog(@"Failed to find address of header!");
            return NO;
        }
        
        DumperLog(@"ASLR slide: 0x%llx", main_address);
        __text_start = main_address;
    }
    
    uint32_t headerProgress = sizeof(struct mach_header_64);
    uint32_t i_lcmd = 0;
    
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
                
                if (l_cmd->cmd == LC_ENCRYPTION_INFO_64) {
                    struct encryption_info_command_64 *newcrypt = (struct encryption_info_command_64 *) curloc;
                    newcrypt->cryptid = 0; // change the cryptid to 0
                    //VERBOSE("dumping binary: patched cryptid");
                } else if (l_cmd->cmd == LC_SEGMENT_64) {
                    //printf("lc segemn yo\n");
                    struct segment_command_64 *newseg = (struct segment_command_64 *) curloc;
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
        DumperLog("attemtping to write to binary");
        
        [newFileHandle writeData:[NSData dataWithBytes:buf length:0x1000]];
        
        sha1(checksum + (20 * pages_d), buf, 0x1000); // perform checksum on the page
        DumperDebugLog("doing checksum yo");
        togo -= 0x1000; // remove a page from the togo
        DumperDebugLog("togo yo %u", togo);
        pages_d += 1; // increase the amount of completed pages
    }
    
    return YES;
}


@end
