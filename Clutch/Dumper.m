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
#import "mach_vm.h"
#import "ASLR.h"

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

@interface NSFileHandle (Private)

- (uint32_t)intAtOffset:(NSUInteger)offset;
- (void)replaceBytesInRange:(NSRange)range withBytes:(const void *)bytes;
- (void)getBytes:(void*)result atOffset:(NSUInteger)offset length:(NSUInteger)length;
- (void)getBytes:(void*)result inRange:(NSRange)range;
//- (bool)hk_readValue:(void*)arg1 ofSize:(unsigned long long)arg2;
//- (bool)hk_writeValue:(const void*)arg1 size:(unsigned long long)arg2;

@end

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

- (BOOL)dump32bitFromFileHandle:(NSFileHandle *__autoreleasing *)fileHandle machHeader:(struct thin_header *)_header
{
    //binaryData.currentOffset = macho.offset + macho.size;
    
    NSFileHandle *_fileHandle = *fileHandle;
    struct thin_header macho = *_header;
    
    [_fileHandle seekToFileOffset:macho.offset + macho.size];
    
    struct linkedit_data_command ldid; // LC_CODE_SIGNATURE load header (for resign)
    struct encryption_info_command crypt; // LC_ENCRYPTION_INFO load header (for crypt*)
    struct segment_command __text; // __TEXT segment
    
    struct super_blob *codesignblob; // codesign blob pointer
    struct code_directory directory; // codesign directory index
    
    BOOL foundCrypt, foundSignature, foundStartText;
    
    uint64_t __text_start = 0;
    
    LOG("32bit dumping: arch %s offset %u", [self readableArchFromHeader:macho].UTF8String, macho.offset);
    
    for (int i = 0; i < macho.header.ncmds; i++) {
        
        uint32_t cmd = [_fileHandle intAtOffset:_fileHandle.offsetInFile];
        uint32_t size = [_fileHandle intAtOffset:_fileHandle.offsetInFile+sizeof(uint32_t)];
        
        switch (cmd) {
            case LC_CODE_SIGNATURE: {
                [_fileHandle getBytes:&ldid inRange:NSMakeRange(_fileHandle.offsetInFile,sizeof(struct linkedit_data_command))];
                foundSignature = YES;
                
                NSLog(@"FOUND CODE SIGNATURE: dataoff %u | datasize %u",ldid.dataoff,ldid.datasize);
                
                break;
            }
            case LC_ENCRYPTION_INFO: {
                [_fileHandle getBytes:&crypt inRange:NSMakeRange(_fileHandle.offsetInFile,sizeof(struct encryption_info_command))];
                foundCrypt = YES;
                
                NSLog(@"FOUND ENCRYPTION INFO: cryptoff %u | cryptsize %u | cryptid %u",crypt.cryptoff,crypt.cryptsize,crypt.cryptid);
                
                break;
            }
            case LC_SEGMENT:
            {
                [_fileHandle getBytes:&__text inRange:NSMakeRange(_fileHandle.offsetInFile,sizeof(struct segment_command))];
                
                if (strncmp(__text.segname, "__TEXT", 6) == 0) {
                    foundStartText = YES;
                    NSLog(@"%s",__text.segname);
                    __text_start = __text.vmaddr;
                }
                break;
            }
        }
        
        [_fileHandle seekToFileOffset:_fileHandle.offsetInFile + size];
        
        if (foundCrypt && foundSignature && foundStartText)
            break;
    }
    
    // we need to have all of these
    if (!foundCrypt || !foundSignature || !foundStartText) {
        NSLog(@"dumping binary: some load commands were not found %@ %@ %@",foundCrypt?@"YES":@"NO",foundSignature?@"YES":@"NO",foundStartText?@"YES":@"NO");
        return NO;
    }
    
    if (patchPIE) {
        NSLog(@"Attempting to remove ASLR on %@",[self readableArchFromHeader:macho]);
        if (macho.header.flags & MH_PIE) {
            macho.header.flags &= ~MH_PIE;
            [_fileHandle replaceBytesInRange:NSMakeRange(macho.offset, sizeof(macho.header)) withBytes:&macho.header];
            
            if (!(macho.header.flags & MH_PIE))
                NSLog(@"Successfully removed ASLR on %@",[self readableArchFromHeader:macho]);
            else
                NSLog(@"Failed to remove ASLR on %@",[self readableArchFromHeader:macho]);
            
        } else {
            NSLog(@"%@ is not protected by ASLR",[self readableArchFromHeader:macho]);
        }
    }
    
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
    
    if ((pid = fork()) == 0) {
        ptrace(PT_TRACE_ME, 0, 0, 0); // trace
        execl(_executable.binaryPath.UTF8String, "", (char *) 0); // import binary memory into executable space
        printf("exit with err code 2 in case we could not import (this should not happen)\n");
        exit(2);
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
        
        [_fileHandle seekToFileOffset:macho.offset + ldid.dataoff];
        
        codesignblob = malloc(ldid.datasize);
        
        [_fileHandle getBytes:codesignblob inRange:NSMakeRange(_fileHandle.offsetInFile, ldid.datasize)];
        
        uint64_t countBlobs = CFSwapInt32(codesignblob->count); // how many indexes?
        
        for (uint64_t index = 0; index < countBlobs; index++) {
            if (CFSwapInt32(codesignblob->index[index].type) == CSSLOT_CODEDIRECTORY) {
                begin = _fileHandle.offsetInFile + CFSwapInt32(codesignblob->index[index].offset);
                [_fileHandle seekToFileOffset:begin];
                [_fileHandle getBytes:&directory inRange:NSMakeRange(begin, sizeof(struct code_directory))];
                break;
            }
        }
        
        free(codesignblob);
        
        uint32_t pages = CFSwapInt32(directory.nCodeSlots); // get the amount of codeslots
        
        if (pages == 0) {
            kill(pid, SIGKILL); // kill the fork
            LOG("pages == 0");
            return FALSE;
        }
        
        NSLog(@"%u",pages);
        
        void *checksum = malloc(pages * 20); // 160 bits for each hash (SHA1)
        uint8_t buf_d[0x1000]; // create a single page buffer
        uint8_t *buf = &buf_d[0]; // store the location of the buffer
        
        // we should only have to write and perform checksums on data that changes
        
        uint32_t togo = crypt.cryptsize + crypt.cryptoff;
        uint32_t total = togo;
        uint32_t pages_d = 0;
        BOOL header = TRUE;
        
        [_fileHandle seekToFileOffset:macho.offset];
        
        /*if ((macho.header.flags & MH_PIE) && !patchPIE)
        {
            mach_vm_address_t main_address;
            if(find_main_binary(pid, &main_address,macho.header) != KERN_SUCCESS) {
                printf("Failed to find address of header!\n");
                return 1;
            }
            
            uint64_t aslr_slide;
            if(get_image_size(main_address, pid, &aslr_slide) == -1) {
                printf("Failed to find ASLR slide!\n");
                return 1;
            }
            
            printf("ASLR slide: 0x%llx\n", aslr_slide);
            
            __text_start = aslr_slide;
        }*/
        
        // in iOS 4.3+, ASLR can be enabled by developers by setting the MH_PIE flag in
        // the mach header flags. this will randomly offset the location of the __TEXT
        // segment, making it slightly difficult to identify the location of the
        // decrypted pages. instead of disabling this flag in the original binary
        // (which is slow, requires resigning, and requires reverting to the original
        // binary after cracking) we instead manually identify the vm regions which
        // contain the header and subsequent decrypted executable code.
        if ((macho.header.flags & MH_PIE) && (!patchPIE)) {
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

        
        
        NSLog(@"this was unexpected");
        
        uint32_t headerProgress = sizeof(struct mach_header);
        uint32_t i_lcmd = 0;
        
        // overdrive dylib load command size
        
        //uint32_t overdrive_size = sizeof(OVERDRIVE_DYLIB_PATH) + sizeof(struct dylib_command);
        //overdrive_size += sizeof(long) - (overdrive_size % sizeof(long)); // load commands like to be aligned by long
        
        
        while (togo > 0) {
            // get a percentage for the progress bar
            
            if ((err = mach_vm_read_overwrite(port, (mach_vm_address_t) __text_start + (pages_d * 0x1000), (vm_size_t) 0x1000, (pointer_t) buf, &local_size)) != KERN_SUCCESS)	{
                
                printf("dumping binary: failed to dump a page (32)\n");
                if (__text_start == 0x4000 && (macho.header.flags & MH_PIE)) {
                    printf("\n=================\n");
                    printf("0x4000 binary detected, attempting to remove MH_PIE flag");
                    printf("\n=================\n\n");
                    free(checksum); // free checksum table
                    kill(pid, SIGKILL); // kill the fork
                    patchPIE = YES;
                    return [self dump32bitFromFileHandle:&_fileHandle machHeader:&macho];
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
            
            [_fileHandle writeData:[NSData dataWithBytes:buf length:0x1000]];
            
            [_fileHandle seekToFileOffset:_fileHandle.offsetInFile + 0x1000];
            
            sha1(checksum + (20 * pages_d), buf, 0x1000); // perform checksum on the page
            printf("doing checksum yo\n");
            togo -= 0x1000; // remove a page from the togo
            printf("togo yo %u\n", togo);
            pages_d += 1; // increase the amount of completed pages
        }
        
        NSLog(@"dumping binary: writing new checksum");
        printf("\n");
        
        [_fileHandle seekToFileOffset:begin + CFSwapInt32(directory.hashOffset)];
        
        [_fileHandle writeData:[NSData dataWithBytes:checksum length:20*pages_d]];
        
        free(checksum); // free checksum table from memory
        kill(pid, SIGKILL); // kill the fork
    }
    
    return YES;
}

- (BOOL)dump64bitFromFileHandle:(NSFileHandle *__autoreleasing *)fileHandle machHeader:(struct thin_header *)header
{
    
    return NO;
}

- (BOOL)removeArchitecture:(struct thin_header*)removeArch
{
    
    NSString *newbinaryPath = [_executable.workingPath stringByAppendingPathComponent:_executable.binaryPath.lastPathComponent];
    
    struct thin_header macho = *removeArch;
    
    fpos_t upperArchpos = 0, lowerArchpos = 0;
    char archBuffer[20];
    
    NSString *lipoPath = [NSString stringWithFormat:@"%@_%@_l", _executable.workingPath,[self readableArchFromHeader:macho]]; // assign a new lipo path
    
    [[NSFileManager defaultManager] copyItemAtPath:newbinaryPath toPath:lipoPath error: NULL];
    
    FILE *lipoOut = fopen([lipoPath UTF8String], "r+"); // prepare the file stream
    char stripBuffer[4096];
    fseek(lipoOut, SEEK_SET, 0);
    fread(&stripBuffer, 4096, 1, lipoOut);
    
    struct fat_header* fh = (struct fat_header*) (stripBuffer);
    struct fat_arch* arch = (struct fat_arch *) &fh[1];
    
    fseek(lipoOut, 8, SEEK_SET); //skip nfat_arch and bin_magic
    BOOL strip_is_last = false;
    
    NSLog(@"searching for copyindex");
    
    for (int i = 0; i < CFSwapInt32(fh->nfat_arch); i++)
    {
        NSLog(@"index %u, nfat_arch %u", i, CFSwapInt32(fh->nfat_arch));
        if (CFSwapInt32(arch->cpusubtype) == macho.header.cpusubtype)
        {
            
            NSLog(@"found the upperArch we want to remove!");
            fgetpos(lipoOut, &upperArchpos);
            
            //check the index of the arch to remove
            if ((i+1) == CFSwapInt32(fh->nfat_arch))
            {
                //it's at the bottom
                NSLog(@"at the bottom!! capitalist scums");
                strip_is_last = true;
            }
            else
            {
                NSLog(@"hola");
            }
        }
        
        fseek(lipoOut, sizeof(struct fat_arch), SEEK_CUR);
        
        arch++;
    }
    
    if (!strip_is_last)
    {
        NSLog(@"strip is not last!");
        fseek(lipoOut, 8, SEEK_SET); //skip nfat_arch and bin_magic! reset yo
        arch = (struct fat_arch *) &fh[1];
        
        for (int i = 0; i < CFSwapInt32(fh->nfat_arch); i++)
        {
            //swap the one we want to strip with the next one below it
            NSLog(@"## iterating archs %u removearch:%u", CFSwapInt32(arch->cpusubtype), macho.header.cpusubtype);
            if (i == (CFSwapInt32(fh->nfat_arch)) - 1)
            {
                NSLog(@"found the lowerArch we want to copy!");
                fgetpos(lipoOut, &lowerArchpos);
            }
            
            fseek(lipoOut, sizeof(struct fat_arch), SEEK_CUR);
            
            arch++;
        }
        
        if ((upperArchpos == 0) || (lowerArchpos == 0))
        {
            NSLog(@"could not find swap swap swap!");
            return false;
        }
        
        //go to the lower arch location
        fseek(lipoOut, lowerArchpos, SEEK_SET);
        fread(&archBuffer, sizeof(archBuffer), 1, lipoOut);
        
        NSLog(@"upperArchpos %lld, lowerArchpos %lld", upperArchpos, lowerArchpos);
        
        //write the lower arch data to the upper arch poistion
        fseek(lipoOut, upperArchpos, SEEK_SET);
        fwrite(&archBuffer, sizeof(archBuffer), 1, lipoOut);
        
        //blank the lower arch position
        fseek(lipoOut, lowerArchpos, SEEK_SET);
    }
    else
    {
        fseek(lipoOut, upperArchpos, SEEK_SET);
    }
    
    memset(archBuffer,'\0',sizeof(archBuffer));
    fwrite(&archBuffer, sizeof(archBuffer), 1, lipoOut);
    
    //change nfat_arch
    uint32_t bin_nfat_arch;
    
    fseek(lipoOut, 4, SEEK_SET); //bin_magic
    fread(&bin_nfat_arch, 4, 1, lipoOut); // get the number of fat architectures in the file
    
    NSLog(@"number of architectures %u", CFSwapInt32(bin_nfat_arch));
    
    bin_nfat_arch = bin_nfat_arch - 0x1000000;
    
    NSLog(@"number of architectures %u", CFSwapInt32(bin_nfat_arch));
    
    fseek(lipoOut, 4, SEEK_SET); //bin_magic
    fwrite(&bin_nfat_arch, 4, 1, lipoOut);
    
    NSLog(@"Written new header to binary!");
    
    fclose(lipoOut);
    
    [[NSFileManager defaultManager] removeItemAtPath:newbinaryPath error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:lipoPath toPath:newbinaryPath error:NULL];
    
    return true;
}

- (NSString *)stripArch:(cpu_subtype_t)keep_arch
{
    NSString *baseName = [_executable.binaryPath lastPathComponent]; // get the basename (name of the binary)
    NSString *baseDirectory = [NSString stringWithFormat:@"%@/", [_executable.binaryPath stringByDeletingLastPathComponent]];
    
    NSLog(@"##### STRIPPING ARCH #####");
    
    NSString* suffix = [NSString stringWithFormat:@"arm%u_lwork", keep_arch];
    NSString *lipoPath = [NSString stringWithFormat:@"%@_%@", _executable.binaryPath, suffix]; // assign a new lipo path
    
    NSLog(@"lipo path %s", [lipoPath UTF8String]);
    
    [[NSFileManager defaultManager] copyItemAtPath:_executable.binaryPath toPath:lipoPath error: NULL];
    
    FILE *lipoOut = fopen([lipoPath UTF8String], "r+"); // prepare the file stream
    char stripBuffer[4096];
    
    fseek(lipoOut, SEEK_SET, 0);
    fread(&stripBuffer, 4096, 1, lipoOut);
    
    struct fat_header* fh = (struct fat_header*) (stripBuffer);
    struct fat_arch* arch = (struct fat_arch *) &fh[1];
    struct fat_arch copy;
    
    BOOL foundarch = FALSE;
    
    fseek(lipoOut, 8, SEEK_SET); //skip nfat_arch and bin_magic
    
    for (int i = 0; i < CFSwapInt32(fh->nfat_arch); i++)
    {
        if (arch->cpusubtype == keep_arch)
        {
            NSLog(@"found arch to keep %u! Storing it", keep_arch);
            foundarch = TRUE;
            
            fread(&copy, sizeof(struct fat_arch), 1, lipoOut);
        }
        else
        {
            fseek(lipoOut, sizeof(struct fat_arch), SEEK_CUR);
        }
        
        arch++;
    }
    
    if (!foundarch)
    {
        NSLog(@"error: could not find arch to keep!");
        return false;
    }
    
    fseek(lipoOut, 8, SEEK_SET);
    fwrite(&copy, sizeof(struct fat_arch), 1, lipoOut);
    
    char data[20];
    
    memset(data,'\0',sizeof(data));
    
    for (int i = 0; i < (CFSwapInt32(fh->nfat_arch) - 1); i++)
    {
        NSLog(@"blanking arch! %u", i);
        fwrite(data, sizeof(data), 1, lipoOut);
    }
    
    //change nfat_arch
    NSLog(@"changing nfat_arch");
    
    uint32_t bin_nfat_arch = 0x1000000;
    
    NSLog(@"number of architectures %u", CFSwapInt32(bin_nfat_arch));
    
    fseek(lipoOut, 4, SEEK_SET); //bin_magic
    fwrite(&bin_nfat_arch, 4, 1, lipoOut);
    
    NSLog(@"Wrote new header to binary!");
    
    fclose(lipoOut);
    
    NSLog(@"copying sc_info files!");
    
    NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
    NSString *sinfPath = [NSString stringWithFormat:@"%@_%@.sinf", scinfo_prefix, suffix];
    NSString *suppPath = [NSString stringWithFormat:@"%@_%@.supp", scinfo_prefix, suffix];
    NSString *supfPath = [NSString stringWithFormat:@"%@_%@.supf", scinfo_prefix, suffix];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[scinfo_prefix stringByAppendingString:@".supf"]])
    {
        [[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".supf"] toPath:supfPath error:NULL];
    }
    
    NSLog(@"sinf file yo %@", sinfPath);
    
    [[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".sinf"] toPath:sinfPath error:NULL];
    [[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".supp"] toPath:suppPath error:NULL];
    
    return lipoPath;
}


@end

@implementation NSFileHandle (Private)

- (void)replaceBytesInRange:(NSRange)range withBytes:(const void *)bytes
{
    unsigned long long oldOffset = self.offsetInFile;
    
    [self seekToFileOffset:range.location];
    
    [self writeData:[NSData dataWithBytes:bytes length:range.length]];
    
    [self seekToFileOffset:oldOffset];
}

- (void)getBytes:(void *)result inRange:(NSRange)range
{
    unsigned long long oldOffset = self.offsetInFile;
    
    [self seekToFileOffset:range.location];
    
    NSData *data = [self readDataOfLength:range.length];
    
    [data getBytes:result length:range.length];
    
    [self seekToFileOffset:oldOffset];
}

- (void)getBytes:(void*)result atOffset:(NSUInteger)offset length:(NSUInteger)length
{
    unsigned long long oldOffset = self.offsetInFile;
    
    [self seekToFileOffset:offset];
    
    NSData *data = [self readDataOfLength:length];
    
    [data getBytes:result length:length];
    
    [self seekToFileOffset:oldOffset];
}

- (const void *)bytesAtOffset:(NSUInteger)offset length:(NSUInteger)size
{
    unsigned long long oldOffset = self.offsetInFile;
    
    [self seekToFileOffset:offset];
    
    const void * result;
    
    NSData *data = [self readDataOfLength:size];
    
    [data getBytes:&result length:size];
    
    [self seekToFileOffset:oldOffset];
    
    return result;
}

- (uint32_t)intAtOffset:(NSUInteger)offset
{
    unsigned long long oldOffset = self.offsetInFile;
    
    [self seekToFileOffset:offset];
    
    uint32_t result;
    
    NSData *data = [self readDataOfLength:sizeof(result)];
    
    [data getBytes:&result length:sizeof(result)];
    
    [self seekToFileOffset:oldOffset];
    
    return result;
}


@end

void sha1(uint8_t *hash, uint8_t *data, size_t size) {
    SHA1Context context;
    SHA1Reset(&context);
    SHA1Input(&context, data, (unsigned)size);
    SHA1Result(&context, hash);
}
