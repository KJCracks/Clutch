//
//  Device.m
//  Clutch
//
//  Created by Zorro on 14/11/13.
//  Copyright (c) 2013 AppAddict. All rights reserved.
//
//  Re-tailored for Clutch

#import "Device.h"
#import "NSData+Reading.h"
#import <mach-o/dyld.h>
#import <mach/machine.h>

@import MachO.loader;

@implementation Device

+ (cpu_type_t)cpu_type {
    const struct mach_header *header = _dyld_get_image_header(0);
    cpu_type_t local_cpu_type = header->cputype;

    return local_cpu_type;
}

+ (cpu_subtype_t)cpu_subtype {
    const struct mach_header *header = _dyld_get_image_header(0);
    cpu_subtype_t local_cpu_subtype = header->cpusubtype;

    return local_cpu_subtype;
}

@end
