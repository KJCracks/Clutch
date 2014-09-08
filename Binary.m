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

typedef enum
{
    COMPATIBLE,
    COMPATIBLE_SWAP,
    NOT_COMPATIBLE,
    FUCK_KNOWS,
} ArchCompatibility;

char buffer[4096];

- (id)initWithApplication:(Application *)app;
{
    if (self = [super init])
    {
        self.application = app;
        self.binaryPath = app.binaryPath;
        self.temporaryPath = [self generateTemporaryPath];
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
    
    cpu_subtype_t this_subtype = CFSwapInt32(subtype);
    
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
    
    if (![[NSFileManager defaultManager] copyItemAtPath:self.binaryPath toPath:[NSString stringWithFormat:@"%@/%@", temporaryPath, self.application.executableName] error:&error])
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

- (void)injectBinary;
{
    
}

- (void)dump
{
    printf("Beginning Dumping...\n");
    
    NSError *error;
    FILE *binary_file = fopen(self.binaryPath.UTF8String, "r+");
    
    if (binary_file == NULL)
    {
        printf("There was an error opening the binary file for preflight\n");
        
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
                switch([self checkDeviceAgainstArchitecture:CFSwapInt32(fat_arch->cputype) subtype:CFSwapInt32(fat_arch->cpusubtype)])
                {
                    case COMPATIBLE:
                    {
                        printf("Cracking architecture: %s\n", [self readableSubtypeName:fat_arch->cpusubtype].UTF8String);
                        
                        if (![self dumpArchitectureToFile:[NSString stringWithFormat:@"%@_%@", self.application.executableName, [self readableSubtypeName:fat_arch->cpusubtype]] error:&error])
                        {
                            NSLog(@"%@", error);
                        }
                        
                        printf("Successfully cracked...\n");
                    }
                    case COMPATIBLE_SWAP:
                    {
                        NSLog(@"%d", CFSwapInt32(fat_arch->cpusubtype));
                        printf("Cracking swappable architecture: %s\n", [self readableSubtypeName:fat_arch->cpusubtype].UTF8String);
                        //swap here
                        //crack here
                        break;
                    }
                    case NOT_COMPATIBLE:
                    {
                        printf("Can't crack an %s segment on this device\n", [self readableSubtypeName:fat_arch->cpusubtype].UTF8String);
                        break;
                    }
                    case FUCK_KNOWS:
                    {
                        printf("Something horrible happened\n");
                        break;
                    }
                }
                fat_arch++;
            }
            
            break;
        }
        case MH_MAGIC:
        {
            /* 32-Bit Thin (armv7, armv7s) */
            NSLog(@"MH_MAGIC");
            struct mach_header *mach_header = (struct mach_header*)(fat_header);
            
            NSLog(@"MH_MAGIC: %@", [self readableSubtypeName:mach_header->cpusubtype]);
            switch ([self checkDeviceAgainstArchitecture:mach_header->cputype subtype:mach_header->cpusubtype])
            {
                case COMPATIBLE:
                {
                    printf("Cracking architecture: %s\n", [self readableSubtypeName:mach_header->cpusubtype].UTF8String);
                    
                    if (![self dumpArchitectureToFile:[NSString stringWithFormat:@"%@_%@", self.application.executableName, [self readableSubtypeName:mach_header->cpusubtype]] error:&error])
                    {
                        NSLog(@"%@", error);
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
        case MH_MAGIC_64:
        {
            /* 64-Bit Thin (AArch64, iPhone 6!!1?!?! #leek) */
            NSLog(@"MH_MAGIC_64");
            struct mach_header_64 *mach_header_64 = (struct mach_header_64*)(fat_header);
            
            NSLog(@"MH_MAGIC_64: %@\n", [self readableSubtypeName:mach_header_64->cpusubtype]);
            
            switch([self checkDeviceAgainstArchitecture:mach_header_64->cputype subtype:mach_header_64->cpusubtype])
            {
                case COMPATIBLE:
                {
                    printf("Cracking architecture: %s\n", [self readableSubtypeName:mach_header_64->cpusubtype].UTF8String);
                    
                    if (![self dumpArchitectureToFile:[NSString stringWithFormat:@"%@_%@", self.application.executableName, [self readableSubtypeName:mach_header_64->cpusubtype]] error:&error])
                    {
                        NSLog(@"%@", error);
                        break;
                    }
                    
                    break;
                }
                case COMPATIBLE_SWAP:
                {
                    printf("Cracking swappable architecture: %s\n", [self readableSubtypeName:mach_header_64->cpusubtype].UTF8String);
                    // Swap before crack
                    //swap here
                    
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
        }
        default:
            NSLog(@"Something went wrong");
            break;
    }
}

- (BOOL)dumpArchitectureToFile:(NSString *)outpath error:(NSError * __autoreleasing *)error
{
    return YES;
}

- (ArchCompatibility)checkDeviceAgainstArchitecture:(cpu_type_t)cpu_type subtype:(cpu_subtype_t)cpu_subtype
{
    cpu_type_t local_cpu_type = [self getLocalCPUType];
    cpu_subtype_t local_cpu_subtype = [self getLocalCPUSubtype];

    cpu_type_t this_cpu_type = cpu_type;
    cpu_subtype_t this_cpu_subtype = cpu_subtype;
    
//    cpu_type_t this_cpu_type = CFSwapInt32(cpu_type);
//    cpu_subtype_t this_cpu_subtype = CFSwapInt32(cpu_subtype);
    
    NSLog(@"Incoming; cpu: %d, sub: %d", this_cpu_type, this_cpu_subtype);
    NSLog(@"ARM: %d", CPU_TYPE_ARM);
    
    switch (this_cpu_type)
    {
        case CPU_TYPE_ARM:
        {
            if (local_cpu_subtype == this_cpu_subtype)
            {
                NSLog(@"CPU_TYPE_ARM: COMPATIBLE");
                return COMPATIBLE;
            }
            else if (local_cpu_subtype > this_cpu_subtype)
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
            if (local_cpu_type >= CPU_TYPE_ARM64)
            {
                if (local_cpu_subtype == this_cpu_subtype)
                {
                    NSLog(@"CPU_TYPE_ARM64: COMPATIBLE");
                    return COMPATIBLE;
                }
                else if (local_cpu_subtype > this_cpu_subtype)
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
