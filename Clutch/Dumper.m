//
//  Dumper.m
//  Clutch
//
//  Created by Anton Titkov on 12.02.15.
//
//

#import "Dumper.h"
#import "Binary.h"
#import "operations.h"
#import "headers.h"
#import "NSData+Reading.h"
#import <dlfcn.h>
#import <mach/mach_traps.h>
#import <mach/mach_init.h>
#import "sha1.h"

#ifdef __LP64__
typedef vm_region_basic_info_data_64_t vm_region_basic_info_data;
typedef vm_region_info_64_t vm_region_info;
#define VM_REGION_BASIC_INFO_COUNT_UNIV VM_REGION_BASIC_INFO_COUNT_64

#else

typedef vm_region_basic_info_data_t vm_region_basic_info_data;
typedef vm_region_info_t vm_region_info;
#define VM_REGION_BASIC_INFO_COUNT_UNIV VM_REGION_BASIC_INFO_COUNT_64
#endif

typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);
void sha1(uint8_t *hash, uint8_t *data, size_t size);

@interface Dumper ()
{
    Binary *_executable;
    BOOL patchPIE;
}
@end

@implementation Dumper

- (instancetype)init
{
    return nil;
}

- (instancetype)initWithBinary:(Binary *)binary
{
    if (!binary) {
        return nil;
    }
    
    if (self = [super init]) {
        _executable = binary;
    }

    return self;
}

- (NSString *)readableArchFromHeader:(struct thin_header)macho
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

- (BOOL)dump32bitWithData:(NSMutableData *)binaryData machHeader:(struct thin_header)macho
{
    binaryData.currentOffset = macho.offset + macho.size;
    
    struct linkedit_data_command ldid; // LC_CODE_SIGNATURE load header (for resign)
    struct encryption_info_command crypt; // LC_ENCRYPTION_INFO load header (for crypt*)
    struct segment_command __text; // __TEXT segment
    
    struct super_blob *codesignblob; // codesign blob pointer
    struct code_directory directory; // codesign directory index
    
    BOOL foundCrypt, foundSignature, foundStartText;

    uint64_t __text_start = 0;
    
    LOG("32bit dumping: arch %s offset %u", [self readableArchFromHeader:macho].UTF8String, macho.offset);
        
    for (int i = 0; i < macho.header.ncmds; i++) {
        if (binaryData.currentOffset >= binaryData.length ||
            binaryData.currentOffset > macho.header.sizeofcmds + macho.size + macho.offset) // dont go past the header
            break;

        uint32_t cmd  = [binaryData intAtOffset:binaryData.currentOffset];
        uint32_t size = [binaryData intAtOffset:binaryData.currentOffset + sizeof(uint32_t)];
        
        switch (cmd) {
            case LC_CODE_SIGNATURE: {
                ldid = *(struct linkedit_data_command *)(binaryData.bytes + binaryData.currentOffset);
                foundSignature = YES;
                binaryData.currentOffset += size;
                break;
            }
            case LC_ENCRYPTION_INFO: {
                crypt = *(struct encryption_info_command *)(binaryData.bytes + binaryData.currentOffset);
                foundCrypt = YES;
                binaryData.currentOffset += size;
                break;
            }
            case LC_SEGMENT:
            {
                __text = *(struct segment_command *)(binaryData.bytes + binaryData.currentOffset);
                
                if (strncmp(__text.segname, "__TEXT", 6) == 0) {
                    foundStartText = YES;
                    __text_start = __text.vmaddr;
                }
                binaryData.currentOffset += size;
                break;
            }
            default:
                binaryData.currentOffset += size;
                break;
        }
        if (foundCrypt && foundSignature && foundStartText)
            break;
    }
    
    // we need to have all of these
    if (!foundCrypt || !foundSignature || !foundStartText) {
        NSLog(@"dumping binary: some load commands were not found %@ %@ %@",foundCrypt?@"YES":@"NO",foundSignature?@"YES":@"NO",foundStartText?@"YES":@"NO");
        return NO;
    }
    
    if (patchPIE) {
        printf("patching pie\n");
        removeASLRFromBinary(binaryData, macho);
    }
    
    pid_t pid; // store the process ID of the fork
    mach_port_t port; // mach port used for moving virtual memory
    kern_return_t err; // any kernel return codes
    int status; // status of the wait
    mach_vm_size_t local_size = 0; // amount of data moved into the buffer
    uint32_t begin;
    
    // open handle to dylib loader
    void *handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
    // load ptrace library into handle
    ptrace_ptr_t ptrace = dlsym(handle, "ptrace");
    
    if ((pid = fork()) == 0) {
        ptrace(PT_TRACE_ME, 0, 0, 0); // trace
        execl(_executable.binaryPath.UTF8String, "", (char *) 0); // import binary memory into executable space
        printf("exit with err code 2 in case we could not import (this should not happen)\n");
        exit(2); // exit with err code 2 in case we could not import (this should not happen)
    } else if (pid < 0) {
        printf("error: Couldn't fork, did you compile with proper entitlements?\n");
        return NO; // couldn't fork
    } else {
        
        do {
            wait(&status);
            if (WIFEXITED( status ))
                return FALSE;
        } while (!WIFSTOPPED( status ));
        
        if ((err = task_for_pid(mach_task_self(), pid, &port) != KERN_SUCCESS)) {
            LOG("ERROR: Could not obtain mach port, did you sign with proper entitlements?");
            kill(pid, SIGKILL); // kill the fork
            return FALSE;
        }
        
        binaryData.currentOffset = macho.offset + ldid.dataoff;
        
        //137092097
        //139191297
        
        NSString *_binaryDumpPath = [_executable.workingPath stringByAppendingPathComponent:_executable.binaryPath.lastPathComponent];
         
        FILE *_target = fopen(_binaryDumpPath.UTF8String, "r+");
         
        codesignblob = malloc(ldid.datasize);
         
        fseek(_target, binaryData.currentOffset, SEEK_SET); // seek to the codesign blob
        fread(codesignblob, ldid.datasize, 1, _target); // read the whole codesign blob
         
        fclose(_target);
        
        uint32_t countBlobs = CFSwapInt32(codesignblob->count); // how many indexes?
        
        // iterate through each index
        for (uint32_t index = 0; index < countBlobs; index++) {
            if (CFSwapInt32(codesignblob->index[index].type) == CSSLOT_CODEDIRECTORY) { // is this the code directory?
                // we'll find the hash metadata in here
                begin = macho.offset + ldid.dataoff + CFSwapInt32(codesignblob->index[index].offset); // store the top of the codesign directory blob
                binaryData.currentOffset = begin;
                directory = *(struct code_directory *)(binaryData.bytes + binaryData.currentOffset);
                break; // break (we don't need anything from this the superblob anymore)
            }
        }
        
        free(codesignblob); // free the codesign blob
        
        uint32_t pages = CFSwapInt32(directory.nCodeSlots); // get the amount of codeslots
        
        if (pages == 0) {
            
            kill(pid, SIGKILL); // kill the fork
            return FALSE;
        }
        
        void *checksum = malloc(pages * 20); // 160 bits for each hash (SHA1)
        uint8_t buf_d[0x1000]; // create a single page buffer
        uint8_t *buf = &buf_d[0]; // store the location of the buffer
                
        // we should only have to write and perform checksums on data that changes
        uint32_t togo = crypt.cryptsize + crypt.cryptoff;
        uint32_t pages_d = 0;
        BOOL header = TRUE;

        binaryData.currentOffset = macho.offset;
        
        if ((macho.header.flags & MH_PIE) && (!patchPIE)) {
            //VERBOSE("dumping binary: ASLR enabled, identifying dump location dynamically");
            // perform checks on vm regions
            memory_object_name_t object;
            vm_region_basic_info_data_t info;
            mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_UNIV;
            mach_vm_address_t region_start = 0;
            mach_vm_size_t region_size = 0;
            vm_region_flavor_t flavor = VM_REGION_BASIC_INFO;
            err = 0;
            
            while (err == KERN_SUCCESS) {
                err = mach_vm_region(port, &region_start, &region_size, flavor, (vm_region_info_t) &info, &info_count, &object);
                
                NSLog(@"32-bit Region Size: %llu %u", region_size, crypt.cryptsize);
                
                if ((uint32_t)region_size == crypt.cryptsize) {
                    break;
                }
                __text_start = region_start;
                region_start += region_size;
                region_size        = 0;
            }
            if (err != KERN_SUCCESS) {
                free(checksum);
                NSLog(@"32-bit mach_vm_error: %u", err);
                printf("ASLR is enabled and we could not identify the decrypted memory region.\n");
                kill(pid, SIGKILL);
                return FALSE;
                
            }
        }
        
        uint32_t headerProgress = sizeof(struct mach_header);
        uint32_t i_lcmd = 0;
        
        while (togo > 0) {
            
            if ((err = mach_vm_read_overwrite(port, (mach_vm_address_t) __text_start + (pages_d * 0x1000), (vm_size_t) 0x1000, (pointer_t) buf, &local_size)) != KERN_SUCCESS)	{
                
                //LOG("Attempting to remove ASLR from binary arch %s",[_dumper readableArchFromHeader:macho].UTF8String);
                
                printf("dumping binary: failed to dump a page (32)\n");
                if (__text_start == 0x4000) {
                    printf("\n=================\n");
                    printf("0x4000 binary detected, attempting to remove MH_PIE flag");
                    printf("\n=================\n\n");
                    free(checksum); // free checksum table
                    kill(pid, SIGKILL); // kill the fork
                    patchPIE = YES;
                    return [self dump32bitWithData:binaryData machHeader:macho];
                }
                free(checksum); // free checksum table
                kill(pid, SIGKILL); // kill the fork
                return FALSE;
            }
            
            
            if (header) {
                // is this the first header page?
                
                // iterate over the header (or resume iteration)
                void *curloc = buf + headerProgress;
                for (;i_lcmd<macho.header.ncmds;i_lcmd++) {
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
                // is overdrive enabled?
                header = FALSE;
            }
        skipoverdrive:
            //printf("attemtping to write to binary\n");
            //fwrite(buf, 0x1000, 1, target); // write the new data to the target
            [binaryData replaceBytesInRange:NSMakeRange(binaryData.currentOffset, 0x1000) withBytes:buf length:0x1000];
            
            binaryData.currentOffset = binaryData.currentOffset + 0x1000;
            
            sha1(checksum + (20 * pages_d), buf, 0x1000); // perform checksum on the page
            //printf("doing checksum yo\n");
            togo -= 0x1000; // remove a page from the togo
            //printf("togo yo %u\n", togo);
            pages_d += 1; // increase the amount of completed pages
        }
        
        binaryData.currentOffset = begin + CFSwapInt64(directory.hashOffset);
        
        [binaryData replaceBytesInRange:NSMakeRange(binaryData.currentOffset, 20*pages_d) withBytes:checksum length:20*pages_d];
        
        free(checksum); // free checksum table from memory
        kill(pid, SIGKILL); // kill the fork
        
        //[binary writeToFile:_binaryDumpPath atomically:YES];
        
    }
    
    return YES;
}

- (BOOL)dump64bitWithData:(NSMutableData *)data machHeader:(struct thin_header)header
{
    
    
    
    return NO;
}

@end

void sha1(uint8_t *hash, uint8_t *data, size_t size) {
    SHA1Context context;
    SHA1Reset(&context);
    SHA1Input(&context, data, (unsigned)size);
    SHA1Result(&context, hash);
}
