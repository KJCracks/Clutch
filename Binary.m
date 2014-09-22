//
//  Binary.m
//  Clutch
//
//  Created by Thomas Hedderwick on 04/09/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#import "Binary.h"
#import "Application.h"

#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <mach-o/dyld.h>
#import <sys/stat.h>
#import <mach/machine.h>

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
    
    if (![[NSFileManager defaultManager] copyItemAtPath:[NSString stringWithFormat:@"%@/SC_Info/%@", self.application.directoryPath, self.application.sinf] toPath:[NSString stringWithFormat:@"%@/%@", temporaryPath, self.application.sinf] error:&error])
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
    }
    
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
    printf("Beginning Dumping...\n");
    
    NSError *error;
    FILE *binary_file = fopen(self.binaryPath.UTF8String, "r+");
    FILE *target_file = fopen(self.targetPath.UTF8String, "r+");
    
    if (binary_file == NULL || target_file == NULL)
    {
        printf("There was an error opening the binary file(s) for dumping\n");
        
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
    
    return YES;
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
    if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@%@", self.temporaryPath, self.application.sinf]])
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
    }
    
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
