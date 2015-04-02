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
#import <mach/mach.h>
#import <mach/mach_traps.h>
#import <mach/mach_init.h>
#import <mach-o/dyld_images.h>

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
    if ((_thinHeader.header.cpusubtype != [Device cpu_subtype]) && (_originalBinary.hasMultipleARMSlices || (_originalBinary.hasARM64Slice && ([Device cpu_type]==CPU_TYPE_ARM64)))) {
        
        NSString* suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:_thinHeader]];
        
        swappedBinaryPath = [_originalBinary.binaryPath stringByAppendingString:suffix];
        newSinf = [_originalBinary.sinfPath stringByAppendingString:suffix];
        newSupp = [_originalBinary.suppPath stringByAppendingString:suffix];

        [self swapArch];
        
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
    
    DumperLog(@"32bit dumping: arch %@ offset %u", [Dumper readableArchFromHeader:_thinHeader], _thinHeader.offset);
    
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
            case LC_ENCRYPTION_INFO: {
                [newFileHandle getBytes:&crypt inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct encryption_info_command))];
                foundCrypt = YES;
                
                DumperDebugLog(@"FOUND ENCRYPTION INFO: cryptoff %u | cryptsize %u | cryptid %u",crypt.cryptoff,crypt.cryptsize,crypt.cryptid);
                
                break;
            }
            case LC_SEGMENT:
            {
                [newFileHandle getBytes:&__text inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct segment_command))];
                
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
    
    BOOL dumpResult = [self _dumpToFileHandle:newFileHandle withEncryptionInfoCommand:(crypt.cryptsize + crypt.cryptoff) pages:pages fromPort:port pid:pid aslrSlide:__text_start];
    
    //find dylibs swag
    
    task_dyld_info_data_t task_dyld_info;
    mach_msg_type_number_t count = TASK_DYLD_INFO_COUNT;
    
    kern_return_t kr = task_info(self, TASK_DYLD_INFO ,(task_info_t)&task_dyld_info, &count);
    if (kr != KERN_SUCCESS) {
        DumperLog(@"Could not find dyld info!??");
        return NO;
    }
    mach_vm_address_t addr = task_dyld_info.all_image_info_addr;
    struct dyld_all_image_infos *info = (struct dyld_all_image_infos*) addr;

    
    printf("%d\n", info->version);
    uint32_t ImageCount = info->infoArrayCount;
    printf("%d\n", ImageCount);
    
    struct mach_header dylib_header;
    
    
    for (int i = 0; i < ImageCount; ++i) {
        struct dyld_image_info ImageInfo = info->infoArray[i];
        uint32_t address = (uint32_t) ImageInfo.imageLoadAddress;
        printf("%s %x\n", ImageInfo.imageFilePath, address);
        
        
        BOOL dumpResult = [self _dumpToFileHandle:newFileHandle withEncryptionInfoCommand:(crypt.cryptsize + crypt.cryptoff) pages:pages fromPort:port pid:pid aslrSlide:__text_start];
        
        //todo: check if that framework exists
   
        struct load_command l_cmd; // generic load comman
    
        uint32_t _address = address + sizeof(struct mach_header);
        
        uint32_t framework_cryptsize;
        mach_vm_size_t local_size = 0;
        
        for (int lc_index = 0; lc_index < ImageInfo.imageLoadAddress->ncmds; lc_index++) { // iterate over each load command
            
            err = mach_vm_read_overwrite(self, _address, sizeof (struct load_command), &l_cmd, &local_size);
            if (err != KERN_SUCCESS) {
                NSLog(@"failed to read load command");
                return false;
            }
            else if (l_cmd.cmd == LC_ENCRYPTION_INFO) {
                //find the cryptsize fuck yea
                struct encryption_info_command crypt;
                mach_vm_read_overwrite(self, _address, sizeof (struct encryption_info_command), &crypt, &local_size);
                framework_cryptsize = crypt.cryptsize;
                
            }
            _address += sizeof(struct segment_command);
        }
        
        
        
        // perform checks on vm regions
        memory_object_name_t object;
        vm_region_basic_info_data_t info;
        //mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT;
        mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT;
        mach_vm_address_t region_start = 0;
        mach_vm_size_t region_size = 0;
        vm_region_flavor_t flavor = VM_REGION_BASIC_INFO;
        err = 0;
        
        mach_vm_address_t address_to_be_dumped;
        
        while (err == KERN_SUCCESS)
        {
            err = mach_vm_region(self, &region_start, &region_size, flavor, (vm_region_info_t) &info, &info_count, &object);
            NSLog(@"32-bit Region Size: %llu %u, start: %llu, %llu", region_size, crypt.cryptsize, region_start, ImageInfo.load_address_);
            
            /*struct vm_region_basic_info {
             vm_prot_t      protection;
             vm_prot_t      max_protection;
             vm_inherit_t       inheritance;
             boolean_t      shared;
             boolean_t      reserved;
             uint32_t       offset; too small for a real offset
             vm_behavior_t       behavior;
             unsigned short      user_wired_count;
             };*/
            
            struct mach_vm_info_region wow;
            NSLog(@"PROTECTED: %u", info.protection);
            NSLog(@"RESERVED: %d", info.reserved);
            NSLog(@"SHARED: %d", info.shared);
            
            if (region_size == crypt.cryptsize)
            {
                NSLog(@"region_size == cryptsize");
                address_to_be_dumped = region_start;
                break;
            }
            
            //memory_text_start = region_start;
            region_start += region_size;
            region_size = 0;
            
        }
        
        if (err != KERN_SUCCESS)
        {
            NSLog(@"failed to ASLR");
            NSLog(@"failed: %s",  mach_error_string(err));
            return 1;
        }
        
        
        mach_vm_offset_t storedump = (mach_vm_offset_t) malloc(crypt.cryptsize);
        NSLog(@"memory text size %llu, file_size %llu", memory_text_size, __text.filesize);
        
        err = mach_vm_read_overwrite(self, region_start, region_size, &storedump, &local_size);
        if (err != KERN_SUCCESS) {
            NSLog(@"failed to dump");
            NSLog(@"failed: %s",  mach_error_string(err));
            return 1;
        }
        NSLog(@"success dumping, writing now");
        //[[NSFileManager defaultManager] copyItemAtPath:framework toPath:@"framework.dump" error:nil];
        FILE* newfile = fopen("framework.dump", "r+");
        fwrite(&storedump, framework_cryptsize, 1, newfile);
        
        //fseek(newfile, off_cryptid, SEEK_SET);
        //crypt->cryptid = 0;
        //fwrite(&crypt, sizeof(struct encryption_info_command), 1, newfile);
        
        NSLog(@"wrote new cryptid, need to resign");
        break;
        
        
        break; //just test one dylib
    }
    
    
    if (![swappedBinaryPath isEqualToString:_originalBinary.binaryPath])
        [[NSFileManager defaultManager]removeItemAtPath:swappedBinaryPath error:nil];
    if (![newSinf isEqualToString:_originalBinary.sinfPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSinf error:nil];
    if (![newSupp isEqualToString:_originalBinary.suppPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSupp error:nil];
    
    return dumpResult;
}

@end
