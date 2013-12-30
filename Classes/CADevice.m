//
//  CADevice.m
//  CrackAddict
//
//  Created by Zorro on 14/11/13.
//  Copyright (c) 2013 AppAddict. All rights reserved.
//

#import "CADevice.h"


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

@end
