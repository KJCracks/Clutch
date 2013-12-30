//
//  CADevice.m
//  CrackAddict
//
//  Created by Zorro on 14/11/13.
//  Copyright (c) 2013 AppAddict. All rights reserved.
//

#import "CADevice.h"
#import <unistd.h>
#import "out.h"


@implementation CADevice

+ (cpu_type_t)cpu_type
{
    static dispatch_once_t pred;
    static cpu_type_t local_cpu_type;
    dispatch_once(&pred, ^{

        const struct mach_header *header = _dyld_get_image_header(0);
        DEBUG("header header header yo %u %u", header->cpusubtype, header->cputype);
        local_cpu_type = header->cputype;
        
    });
    return local_cpu_type;
}

+ (cpu_subtype_t)cpu_subtype
{
    static dispatch_once_t pred;
    static cpu_subtype_t local_cpu_subtype;
    dispatch_once(&pred, ^{
        
        const struct mach_header *header = _dyld_get_image_header(0);
        DEBUG("header header header yo %u %u", header->cpusubtype, header->cputype);
        local_cpu_subtype = header->cpusubtype;
    });
    return local_cpu_subtype;
}
+ (ArchCompatibility)compatibleWith:(struct fat_arch*) arch {
    cpu_type_t cputype = CFSwapInt32(arch->cputype);
    cpu_subtype_t cpusubtype = CFSwapInt32(arch->cpusubtype);
    
    
    if ((cpusubtype != [self cpu_subtype]) || (cputype != [self cpu_type])) {
        //not same, definitely swap or no
        if (([self cpu_type] == CPU_TYPE_ARM) && (cpusubtype > [self cpu_subtype])) {
            DEBUG("Can't crack 32bit arch %d on %d! not compatible", cpusubtype, [self cpu_subtype]);
            return NOT_COMPATIBLE;
        }
        else if (cputype == CPU_TYPE_ARM64) {
            if (([self cpu_type] == CPU_TYPE_ARM64) && (cpusubtype > [self cpu_subtype])) {
                DEBUG("Can't crack 64bit arch %d on %d! skipping", cpusubtype, [self cpu_subtype]);
                return NOT_COMPATIBLE;
            }
            else if ([self cpu_type] == CPU_TYPE_ARM) {
                DEBUG("Can't crack 64bit arch on this device! skipping");
                return NOT_COMPATIBLE;
            }
        }
        if ([self cpu_type] == CPU_TYPE_ARM64) {
            return COMPATIBLE_STRIP;
        }
        else {
            return COMPATIBLE_SWAP;
        }
       
    }
    
    return COMPATIBLE;
}
@end
