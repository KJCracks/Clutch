//
//  Binary.m
//  Clutch
//
//  Created by Thomas Hedderwick on 04/09/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#import "Binary.h"
#import "Application.h"
#import "out.h"


#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <mach-o/dyld.h>
#import <sys/stat.h>
#import <mach/machine.h>
#import <dlfcn.h>
#import <mach/mach_traps.h>
#import <mach/vm_map.h>
#import <mach/vm_region.h>
#import <mach/mach.h>

#define PT_TRACE_ME 0
#define CSSLOT_CODEDIRECTORY 0

#ifdef __LP64__
typedef vm_region_basic_info_data_64_t vm_region_basic_info_data;
typedef vm_region_info_64_t vm_region_info;
#define VM_REGION_BASIC_INFO_COUNT_UNIV VM_REGION_BASIC_INFO_COUNT_64

#else

typedef vm_region_basic_info_data_t vm_region_basic_info_data;
typedef vm_region_info_t vm_region_info;
#define VM_REGION_BASIC_INFO_COUNT_UNIV VM_REGION_BASIC_INFO_COUNT_64
#endif


@implementation Binary

char buffer[4096];
typedef enum
{
    COMPATIBLE,
    COMPATIBLE_SWAP,
    NOT_COMPATIBLE,
    FUCK_KNOWS,
} ArchCompatibility;

- (id)initWithApplication:(Application *)app;
{
    if (self = [super init])
    {
        self.application = app;
        self.binaryPath = app.binaryPath;
        self.temporaryPath = [self generateTemporaryPath];
        self.local_cpu_subtype = [self getLocalCPUSubtype];
        self.local_cpu_type = [self getLocalCPUType];
    }
    
    return self;
}

- (cpu_type_t)getLocalCPUType
{
    const struct mach_header *header = _dyld_get_image_header(0);
    
    return header->cputype;
}

- (cpu_subtype_t)getLocalCPUSubtype
{
    const struct mach_header *header = _dyld_get_image_header(0);
    
    return header->cpusubtype;
}


- (NSString *)readableSubtypeName:(cpu_subtype_t)subtype
{
    NSString *name;
    
    cpu_subtype_t this_subtype = CFSwapInt32HostToLittle(subtype);
    
    switch (this_subtype)
    {
        case CPU_SUBTYPE_ARM_V7:
        {
            name = @"armv7";
            break;
        }
        case CPU_SUBTYPE_ARM_V7S:
        {
            name = @"armv7s";
            break;
        }
        case CPU_SUBTYPE_ARM64_ALL:
        {
            name = @"arm64";
            break;
        }
        case CPU_SUBTYPE_ARM64_V8:
        {
            name = @"arm64v8";
            break;
        }
        default:
        {
            name = @"unknown";
            break;
        }
    }
    
    return name;
}

- (NSString *)generateTemporaryPath
{
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    int length = 8;
    
    NSMutableString *randomGarbage = [NSMutableString stringWithCapacity:length];
    
    for (int i = 0; i < length; i++)
    {
        [randomGarbage appendFormat:@"%C", [letters characterAtIndex:arc4random() % letters.length]];
    }
    
    NSString *temporaryPath = [NSString stringWithFormat:@"/tmp/clutch_%@/", randomGarbage];
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtPath:temporaryPath withIntermediateDirectories:NO attributes:nil error:&error])
    {
        NSLog(@"Create error: %@", error);
        return nil;
    }
    
    self.targetPath = [NSString stringWithFormat:@"%@%@", temporaryPath, self.application.executableName];
    if (![[NSFileManager defaultManager] copyItemAtPath:self.binaryPath toPath:self.targetPath error:&error])
    {
        NSLog(@"Copy error: %@", error);
        return nil;
    }
#warning refactor this
    // Find SCI_Info keys
    /*if (![[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithFormat:@"%@/SC_Info/%@", self.application.directoryPath, self.application.sinf] toPath:[NSString stringWithFormat:@"%@/%@", temporaryPath, self.application.sinf] error:&error])
    {
        NSLog(@"%@", error);
        return nil;
    }
    
    if (self.application.sinf)
    {
        if (![[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithFormat:@"%@/SC_Info/%@", self.application.directoryPath, self.application.supp] toPath:[NSString stringWithFormat:@"%@/%@", temporaryPath, self.application.supp] error:&error])
        {
            NSLog(@"%@", error);
            return nil;
        }
    }
    
    if (self.application.supf)
    {
        if (![[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithFormat:@"%@/SC_Info/%@", self.application.directoryPath, self.application.supf] toPath:[NSString stringWithFormat:@"%@/%@", temporaryPath, self.application.supf] error:&error])
        {
            NSLog(@"%@", error);
            return nil;
        }
    }*/
    
    return temporaryPath;
}

- (void)cleanUp
{
    /* Remove temporary folder */
    NSError *error;
    if (![[NSFileManager defaultManager] removeItemAtPath:self.temporaryPath error:&error])
    {
        NSLog(@"%@", error);
    }
}

- (void)dump
{
    NOTIFY("Beginning Dumping...");
    
    NSError *error;
    FILE *binary_file = fopen(self.binaryPath.UTF8String, "r+");
    FILE *target_file = fopen(self.targetPath.UTF8String, "r+");
    
    if (binary_file == NULL || target_file == NULL)
    {
        ERROR("There was an error opening the binary file(s) for dumping");
        
        return;
    }
    
    fread(&buffer, sizeof(buffer), 1, binary_file);
    
    struct fat_header *fat_header = (struct fat_header *)(buffer);

    
    switch (fat_header->magic) {
        case FAT_CIGAM:
        {
            /* Fat binary found */
            NSLog(@"FAT_CIGAM");
            struct fat_arch *fat_arch = (struct fat_arch*)(&fat_header[1]);
            
            for (int i = 0; i < CFSwapInt32(fat_header->nfat_arch); i++)
            {
                /* idk why I have to switch the byte encoding twice... kinda annoying */
                switch([self checkDeviceAgainstArchitecture:CFSwapInt32HostToBig(fat_arch->cputype) subtype:CFSwapInt32HostToBig(fat_arch->cpusubtype)])
                {
                    case COMPATIBLE:
                    {
                        printf("Cracking architecture: %s\n", [self readableSubtypeName:CFSwapInt32HostToBig(fat_arch->cpusubtype)].UTF8String);
                        
                        if (![self dumpBinary:binary_file atPath:self.binaryPath toFile:target_file atPath:self.targetPath withTop:fat_arch->offset error:&error])
                        {
                            NSLog(@"Dump Error: %@", error);
                        }
                        
                        printf("Successfully cracked...\n");
                    }
                    case COMPATIBLE_SWAP:
                    {
                        NSLog(@"%d", CFSwapInt32HostToBig(fat_arch->cpusubtype));
                        printf("Cracking swappable architecture: %s\n", [self readableSubtypeName:CFSwapInt32HostToBig(fat_arch->cpusubtype)].UTF8String);
                        //swap here
                        //crack here
                        
                        if (![self swapArchitecture:fat_arch->cpusubtype])
                        {
                            NSLog(@"Swap Error: Failed to swap? (WTF)?");
                            // strip it?
                            break;
                        }
                        
                        if (![self dumpBinary:binary_file atPath:self.binaryPath toFile:target_file atPath:self.targetPath withTop:fat_arch->offset error:&error])
                        {
                            if (error)
                            {
                                NSLog(@"Dump Error: %@", error);
                            }
                            
                            break;
                        }
                        
                        printf("Successfully swapped\n");
                        
                        break;
                    }
                    case NOT_COMPATIBLE:
                    {
                        printf("Crack Warning: Can't crack an %s segment on this device\n", [self readableSubtypeName:CFSwapInt32HostToBig(fat_arch->cpusubtype)].UTF8String);
                        // strip arch out of binary
                        // live a long and peaceful life
                        break;
                    }
                    case FUCK_KNOWS:
                    {
                        printf("Error: Something horrible happened\n");
                        break;
                    }
                }
                fat_arch++;
            }
            
            break;
        }
        case MH_MAGIC:
        case MH_MAGIC_64:
        {
            /* 32-Bit Thin (armv7, armv7s) or */
            /* 64-bit Thin (arm64_v8, arm64_iphone6) */
            // Someone test this plz
            NSLog(@"MH_MAGIC");
            struct mach_header *mach_header = (struct mach_header*)(fat_header);
            
            NSLog(@"MH_MAGIC: %@", [self readableSubtypeName:mach_header->cpusubtype]);
            switch ([self checkDeviceAgainstArchitecture:mach_header->cputype subtype:mach_header->cpusubtype])
            {
                case COMPATIBLE:
                {
                    printf("Cracking architecture: %s\n", [self readableSubtypeName:mach_header->cpusubtype].UTF8String);
                    
                    if (![self dumpBinary:binary_file atPath:self.binaryPath toFile:target_file atPath:self.targetPath withTop:0 error:&error])
                    {
                        NSLog(@"Dump Error: %@", error);
                        break;
                    }
                    
                    printf("Successfully cracked...\n");
                    
                    break;
                }
                case COMPATIBLE_SWAP:
                {
                    printf("Cracking swappable architecture: %s\n", [self readableSubtypeName:mach_header->cpusubtype].UTF8String);
                    //swap here
                    //crack here
                    
                    if (![self swapArchitecture:mach_header->cpusubtype])
                    {
                        NSLog(@"Swap Error: Failed to swap? (WTF)?");
                        // strip it?
                        break;
                    }
                    
                    if (![self dumpBinary:binary_file atPath:self.binaryPath toFile:target_file atPath:self.targetPath withTop:0 error:&error])
                    {
                        if (error)
                        {
                            NSLog(@"Dump Error: %@", error);
                        }
                        
                        break;
                    }

                    break;
                }
                case NOT_COMPATIBLE:
                {
                    printf("Can't crack a 64-bit thin binary on this device (who let you install this??)\n");
                    break;
                }
                case FUCK_KNOWS:
                {
                    printf("Something went horribly wrong.\n");
                    break;
                }
            }
            
            break;
        }
//        case MH_MAGIC_64:
//        {
//            /* 64-Bit Thin (AArch64, iPhone 6!!1?!?! #leek) */
//            NSLog(@"MH_MAGIC_64");
//            struct mach_header_64 *mach_header_64 = (struct mach_header_64*)(fat_header);
//            
//            NSLog(@"MH_MAGIC_64: %@\n", [self readableSubtypeName:mach_header_64->cpusubtype]);
//            
//            switch([self checkDeviceAgainstArchitecture:mach_header_64->cputype subtype:mach_header_64->cpusubtype])
//            {
//                case COMPATIBLE:
//                {
//                    printf("Cracking architecture: %s\n", [self readableSubtypeName:mach_header_64->cpusubtype].UTF8String);
//                    
//                    if (![self dumpBinary:binary_file atPath:self.binaryPath toFile:target_file atPath:self.targetPath withTop:0 error:&error])
//                    {
//                        NSLog(@"%@", error);
//                        break;
//                    }
//                    
//                    break;
//                }
//                case COMPATIBLE_SWAP:
//                {
//                    printf("Cracking swappable architecture: %s\n", [self readableSubtypeName:mach_header_64->cpusubtype].UTF8String);
//                    // Swap before crack
//                    //swap here
//                    
//                    if (![self swapArchitecture:mach_header_64->cpusubtype])
//                    {
//                        NSLog(@"Failed to swap? (WTF)?");
//                        // strip it?
//                        break;
//                    }
//                    
//                    if (![self dumpBinary:binary_file atPath:self.binaryPath toFile:target_file atPath:self.targetPath withTop:0 error:&error])
//                    {
//                        if (error)
//                        {
//                            NSLog(@"Dump Error: %@", error);
//                        }
//                        
//                        break;
//                    }
//
//                    break;
//                }
//                case NOT_COMPATIBLE:
//                {
//                    printf("Can't crack a 64-bit thin binary on this device (who let you install this??)\n");
//                    break;
//                }
//                case FUCK_KNOWS:
//                {
//                    printf("Something went horribly wrong.\n");
//                    break;
//                }
//            }
//        }
        default:
            NSLog(@"Error: Not a Mach-O file?");
            break;
    }
}

- (BOOL)dumpBinary:(FILE *)origin atPath:(NSString *)originPath toFile:(FILE *)target atPath:(NSString *)targetPath withTop:(uint32_t)top error:(NSError **)error
{
    /* Go to top of target, save top position */
    fseek(target, top, SEEK_SET);
    fpos_t top_position;
    fgetpos(target, &top_position);
    
    /* Load Command structures */
    struct linkedit_data_command ldid; // LC_CODE_SIGNATURE (for resign)
    struct encryption_info_command crypt; // LC_ENCRYPTION_INFO (for crypt*)
    struct mach_header mach; // Generic MH
    struct load_command l_cmd; // Generic LC
    struct segment_command __text; // __TEXT seg
    
    struct SuperBlob *codesignBlob; // Codesign blob pointer
    struct CodeDirectory directory; // Codesign directory index
    
    BOOL foundCrypt = FALSE;
    BOOL foundSignature = FALSE;
    BOOL foundStartText = FALSE;
    
    uint32_t __text_start = 0;
    
    printf("Analysing Load Commands...\n");
    
    fread(&mach, sizeof(struct mach_header), 1, target); // Read mach header to get ncmds
    
    for (int lc_index = 0; lc_index < mach.ncmds; lc_index++)
    {
        fread(&l_cmd, sizeof(struct load_command), 1, target); // Read LC from binary
        
        switch (l_cmd.cmd) {
            case LC_ENCRYPTION_INFO:
            case LC_ENCRYPTION_INFO_64:
            {
                /* Encryption Info LC */
                fseek(target, -1 * sizeof(struct load_command), SEEK_CUR); // Seek back a LC
                fread(&crypt, sizeof(struct encryption_info_command), 1, target); // Store the crypt info
                
                foundCrypt = TRUE;
                NSLog(@"Found LC_ENCRYPTION_INFO");
                
                break;
            }
            case LC_CODE_SIGNATURE:
            {
                /* Code Signature */
                fseek(target, -1 * sizeof(struct load_command), SEEK_CUR); // Seek back a LC
                fread(&ldid, sizeof(struct linkedit_data_command), 1, target); // Store the ldid info
                
                foundSignature = TRUE;
                NSLog(@"Found LC_CODE_SIGNATURE");
                
                break;
            }
            case LC_SEGMENT:
            case LC_SEGMENT_64:
            {
                /* Segments (we're looking for __TEXT) */
                
                // Some applications, like Skype, have decided to start offsetting the executable image's
                // vm region by substantial amounts for no apparant reason. This will find the vmaddr of
                // that segment (referenced later during dumping)
                fseek(target, -1 * sizeof(struct load_command), SEEK_CUR);
                fread(&__text, sizeof(struct segment_command), 1, target);
                
                if (strncmp(__text.segname, "__TEXT", 6) == 0)
                {
                    foundStartText = TRUE;
                    NSLog(@"Found __TEXT's start");
                    __text_start = __text.vmaddr;
                }
                
                fseek(target, l_cmd.cmdsize - sizeof(struct segment_command), SEEK_CUR); // Seek over segment
                break;
            }
            default:
            {
                if (foundCrypt && foundSignature && foundStartText)
                {
                    break;
                }
                
                fseek(target, l_cmd.cmdsize - sizeof(struct load_command), SEEK_CUR); // Seek over this load command
                break;
            }
        }
    }
    
    if (!foundCrypt || !foundSignature || !foundStartText)
    {
        printf("dumping: couldn't find some load commands\n");
        return FALSE;
    }
    
    /* TODO: Normally we patch PIE here - do we *still* have to do this? */
    BOOL patchPIE = FALSE;
    
    if (patchPIE)
    {
        printf("dumping: patching PIE\n");
        
        mach.flags &= ~MH_PIE;
        
        fseek(origin, top, SEEK_SET);
        fwrite(&mach, sizeof(struct mach_header), 1, origin);
    }
    
    pid_t pid; // Store the process id of the fork
    mach_port_t port; // Mach port used for moving virtual memory
    kern_return_t err; // any kernel return codes
    mach_vm_size_t local_size = 0; // Amount of data moved into the buffer
    int status; // Status of the wait
    uint32_t begin;
    
    printf("dumping: obtaining ptrace handle\n");
    
    void *handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW); // Open handle to the dylib loader
    ptrace_ptr_t ptrace = dlsym(handle, "ptrace");
    
    printf("dumping: beginning forking\n");
    
    if ((pid = fork()) == 0)
    {
        // it worked! the magic is in allowing the process to trace before execl.
        // the process will be incapatable of preventing itself from tracing
        // execl stops the process before this is capable
        // PT_DENY_ATTACH was never meant to be good security, only a minor roadblock
        
        ptrace(PT_TRACE_ME, 0, 0, 0); // ptrace
        execl(originPath.UTF8String, "", (char *)0); // import binary memory into executable space
        
        exit(2); // exit with error 2 in case we could not import binary to memory (shouldn't happen)
    }
    else if (pid < 0)
    {
        printf("error: Couldn't fork process did you sign with proper entitlements?\n");
        return FALSE;
    }
    else
    {
        /* wait until process stops */
        do
        {
            wait(&status);
            
            if (WIFEXITED(status))
            {
                return FALSE;
            }
        }
        while (!WIFSTOPPED(status));
    }
    
    printf("dumping: obtaining Mach port\n");
    
    /* open mach port to other process */
    
    if ((err = task_for_pid(mach_task_self(), pid, &port) != KERN_SUCCESS))
    {
        printf("error: Couldn't obtain mach port, did you sign with proper entitlements?\n");
        
        kill(pid, SIGKILL);
        return FALSE;
    }
    
    printf("dumping: preparing code resign\n");
    
    codesignBlob = malloc(ldid.datasize);
    
    fseek(target, top + ldid.dataoff, SEEK_SET); // Seek to the codesign blob
    fread(codesignBlob, ldid.datasize, 1, target); // Read the whole blob
    uint32_t countBlobs = CFSwapInt32(codesignBlob->count); // How many indices?
    
    for (uint32_t index = 0; index < countBlobs; index++)
    {
        if (CFSwapInt32(codesignBlob->index[index].type) == CSSLOT_CODEDIRECTORY) // Is this the code directory?
        {
            /* We will find the hash metadata in here */
            begin = top + ldid.dataoff + CFSwapInt32(codesignBlob->index[index].offset); // Store the top of the codesign blob
            
            fseek(target, begin, SEEK_SET); // Seek to the beginning of the blog
            fread(&directory, sizeof(struct CodeDirectory), 1, target); // read the whole blob
            
            break; // Don't need anything from this superblob anymore
        }
    }
    
    free(codesignBlob); // Free the codesign blob
    
    uint32_t pages = CFSwapInt32(directory.nCodeSlots); // Get the amount of codeslots
    
    if (pages == 0)
    {
        kill(pid, SIGKILL); // kill fork
        
        return FALSE;
    }
    
    void *checksum = malloc(pages * 20); // 160 bits for each hash (SHA1)
    
    uint8_t buff_p[0x1000]; // create a single page buffer
    uint8_t *buff = &buff_p[0]; // Store the locaiton of the buffer
    
    printf("dumping: prepairing to dump\n");
    
    /* We should only have to write and perform checksums on data that changes */
    uint32_t togo = crypt.cryptsize + crypt.cryptoff;
    uint32_t total = togo;
    uint32_t pages_d = 0;
    BOOL header = TRUE;
    
    /* Write the header */
    fsetpos(target, &top_position);
    
    // in iOS 4.3+, ASLR can be enabled by developers by setting the MH_PIE flag in
    // the mach header flags. this will randomly offset the location of the __TEXT
    // segment, making it slightly difficult to identify the location of the
    // decrypted pages. instead of disabling this flag in the original binary
    // (which is slow, requires resigning, and requires reverting to the original
    // binary after cracking) we instead manually identify the vm regions which
    // contain the header and subsequent decrypted executable code.
    if ((mach.flags & MH_PIE) && (!patchPIE))
    {
        printf("dumping: ASLR enabled, identifying dump location dynamically\n");
        
        /* Perform checks on vm regions */
        memory_object_name_t object;
        vm_region_basic_info_data_t info;
        mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_UNIV;
        mach_vm_address_t region_start = 0;
        mach_vm_size_t region_size = 0;
        vm_region_flavor_t flavor = VM_REGION_BASIC_INFO;
        err = 0;
        
        while (err == KERN_SUCCESS)
        {
            //err = mach_vm_region(port, &region_start, &region_size, flavor, (vm_region_info_t) &info, &info_count, &object);
            
            NSLog(@"region size: %llu crypt_siz: %u", region_size, crypt.cryptsize);
            
            if (region_size == crypt.cryptsize)
            {
                NSLog(@"region_size == cryptsize");
                
                break;
            }
            
            __text_start = region_start;
            region_start += region_size;
            region_size = 0;
        }
        
        if (err != KERN_SUCCESS)
        {
            NSLog(@"mach_vm_error: %u", err);
            printf("ALSR is enabled and we could not identify the decrypted memory region.\n");
            
            free(checksum);
            kill(pid, SIGKILL);
            
            return FALSE;
        }
    }
    
    uint32_t header_progress = sizeof(struct mach_header); // TODO: 64 bit tho
    uint32_t i_lcmd = 0;
    
    // Some overdrive stuff here eventually
    
    printf("dumping: performing dump\n");
    
    while (togo > 0)
    {
        // Get percentage for progress bar here at some point. 
    }
    
    return TRUE;
}

- (BOOL)lipoBinary:(FILE *)binary
{
    /* Lipo architectures out to their own files so they can be individually cracked */
    
    return YES;
}

- (BOOL)swapArchitecture:(cpu_subtype_t)swap_subtype
{
    if (self.local_cpu_subtype == swap_subtype)
    {
        /* Arch doesn't need to be swapped... */
        return YES;
    }
    
    char swap_buffer[4096];
    
    NSString *swapBinaryPath = [NSString stringWithFormat:@"%@_%@_lwork", self.temporaryPath, [self readableSubtypeName:OSSwapInt32(swap_subtype)]];
    
    NSError *error;
    if (![[NSFileManager defaultManager] copyItemAtPath:self.binaryPath toPath:swapBinaryPath error:&error])
    {
        NSLog(@"Swap Error: %@", error);
        
        return FALSE;
    }
    
    FILE *swap_binary = fopen(swapBinaryPath.UTF8String, "r+");
    
    fseek(swap_binary, 0, SEEK_SET);
    fread(&swap_buffer, sizeof(swap_buffer), 1, swap_binary);
    
    /* Get the header */
    struct fat_header *swap_fat_header = (struct fat_header *)(swap_buffer);
    struct fat_arch *arch = (struct fat_arch *)&swap_fat_header[1];
    
    cpu_type_t cpu_type_to_swap = 0;
    cpu_subtype_t largest_cpu_subtype = 0;
    
    /* Interate the archs in the header, hopefully we find a swap */
    for (int i = 0; i < CFSwapInt32(swap_fat_header->nfat_arch); i++)
    {
        if (arch->cpusubtype == swap_subtype)
        {
            NSLog(@"found cpu type to swap to: %@\n", [self readableSubtypeName:swap_subtype]);
            cpu_type_to_swap = arch->cputype;
        }
        
        if (arch->cpusubtype > largest_cpu_subtype)
        {
            largest_cpu_subtype = arch->cpusubtype;
        }
        
        arch++;
    }
    
    /* Reset our arch structure */
    arch = (struct fat_arch *)&swap_fat_header[1];
    
    
    /* Actually perform the swap swap attack */
    for (int i = 0; i < CFSwapInt32(swap_fat_header->nfat_arch); i++)
    {
        if (arch->cpusubtype == largest_cpu_subtype)
        {
            if (cpu_type_to_swap != arch->cputype)
            {
                NSLog(@"ERROR: cpu types are incompatible.");
                return FALSE;
            }
            
            arch->cpusubtype = swap_subtype;
        }
        else if (arch->cpusubtype == swap_subtype)
        {
            arch->cpusubtype = largest_cpu_subtype;
            NSLog(@"Replaced %@'s cpu subtype with %@", [self readableSubtypeName:CFSwapInt32(arch->cpusubtype)], [self readableSubtypeName:CFSwapInt32(largest_cpu_subtype)]);
        }
        
        arch++;
    }
    
    /* Write new header to binary */
    fseek(swap_binary, 0, SEEK_SET);
    fwrite(swap_buffer, sizeof(swap_buffer), 1, swap_binary);
    fclose(swap_binary);
    
    /* Move the SC_Info keys, this is because caching will make the OS load up the old arch */
#warning refactor this
    /*if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@%@", self.temporaryPath, self.application.sinf]])
    {
        if (![[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithFormat:@"%@%@", self.temporaryPath, self.application.sinf] toPath:[NSString stringWithFormat:@"%@%@_lwork", self.temporaryPath, self.application.sinf] error:nil])
        {
            NSLog(@"Failed to move SC_INFO sinf");
        }
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@%@", self.temporaryPath, self.application.supp]])
    {
        if (![[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithFormat:@"%@%@", self.temporaryPath, self.application.supp] toPath:[NSString stringWithFormat:@"%@%@_lwork", self.temporaryPath, self.application.supp] error:nil])
        {
            NSLog(@"Failed to move SC_INFO supp");
        }
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@%@", self.temporaryPath, self.application.supf]])
    {
        if (![[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithFormat:@"%@%@", self.temporaryPath, self.application.supf] toPath:[NSString stringWithFormat:@"%@%@_lwork", self.temporaryPath, self.application.supf] error:nil])
        {
            NSLog(@"Failed to move SC_INFO supf");
        }
    }*/
    
    return TRUE;
}

- (ArchCompatibility)checkDeviceAgainstArchitecture:(cpu_type_t)cpu_type subtype:(cpu_subtype_t)cpu_subtype
{
    cpu_type_t this_cpu_type = CFSwapInt32HostToLittle(cpu_type);
    cpu_subtype_t this_cpu_subtype = CFSwapInt32HostToLittle(cpu_subtype);
    
    NSLog(@"Incoming; cpu: %d, sub: %d", this_cpu_type, this_cpu_subtype);
    NSLog(@"ARM: %d", CPU_TYPE_ARM);
    
    switch (this_cpu_type)
    {
        case CPU_TYPE_ARM:
        {
            if (self.local_cpu_subtype == this_cpu_subtype)
            {
                NSLog(@"CPU_TYPE_ARM: COMPATIBLE");
                return COMPATIBLE;
            }
            else if (self.local_cpu_subtype > this_cpu_subtype)
            {
                NSLog(@"CPU_TYPE_ARM: COMPATIBLE SWAP");
                return COMPATIBLE_SWAP;
            }
            else
            {
                NSLog(@"CPU_TYPE_ARM: NOT COMPATIBLE");
                return NOT_COMPATIBLE;
            }
            break;
        }
        case CPU_TYPE_ARM64:
        {
            if (self.local_cpu_type >= CPU_TYPE_ARM64)
            {
                if (self.local_cpu_subtype == this_cpu_subtype)
                {
                    NSLog(@"CPU_TYPE_ARM64: COMPATIBLE");
                    return COMPATIBLE;
                }
                else if (self.local_cpu_subtype > this_cpu_subtype)
                {
                    NSLog(@"CPU_TYPE_ARM64 COMPATIBLE SWAP");
                    return COMPATIBLE_SWAP;
                }
            }
            else
            {
                NSLog(@"CPU_TYPE_ARM64: NOT COMPATIBLE");
                return NOT_COMPATIBLE;
            }
            break;
        }
        default:
        {
            NSLog(@"!!!!CPU_TYPE_NOT_ARM!!!!!");
            return FUCK_KNOWS;
            break;
        }
    }
    
    return FUCK_KNOWS;
}

@end
