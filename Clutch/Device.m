//
//  Device.m
//  CrackAddict
//
//  Created by Zorro on 14/11/13.
//  Copyright (c) 2013 AppAddict. All rights reserved.
//
//  Re-tailored for Clutch

#import "Device.h"
#import <mach/machine.h>
#import <mach-o/dyld.h>
#import "NSData+Reading.h"

@import MachO.loader;

@implementation Device

+ (cpu_type_t)cpu_type
{
    const struct mach_header *header = _dyld_get_image_header(0);
    cpu_type_t local_cpu_type = header->cputype;
    
    return local_cpu_type;
}

+ (cpu_subtype_t)cpu_subtype
{
    const struct mach_header *header = _dyld_get_image_header(0);
    cpu_subtype_t local_cpu_subtype = header->cpusubtype;
    
    return local_cpu_subtype;
}

+ (NSData *)libClutch
{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    
    const struct section* sect;
    NSData *binary = [NSData dataWithContentsOfFile:processInfo.arguments[0]];
    
    struct thin_header headers[4];
    uint32_t numHeaders = 0;
    headersFromBinary(headers, binary, &numHeaders);
    
    struct thin_header macho = headers[0];
    
    binary.currentOffset = macho.offset + macho.size;
    
    NSData *_key = nil;
    
    for (int i = 0; i < macho.header.ncmds; i++) {
        if (binary.currentOffset >= binary.length ||
            binary.currentOffset > macho.header.sizeofcmds + macho.size + macho.offset)
            break;
        
        uint32_t cmd  = [binary intAtOffset:binary.currentOffset];
        uint32_t size = [binary intAtOffset:binary.currentOffset + sizeof(uint32_t)];
        
        struct segment_command * command = (struct segment_command *)(binary.bytes + binary.currentOffset);
        
        if (((cmd == LC_SEGMENT) || (cmd == LC_SEGMENT_64)) && (strcmp(command->segname, "__RESTRICT") == 0))
        {
            const struct section* const sectionsStart = (struct section*)((char*)command + sizeof(struct segment_command));
            const struct segment_command* const sectionsEnd = &sectionsStart[command->nsects];
            
            for (sect=sectionsStart; sect < sectionsEnd; ++sect) {
                
                if (strcmp(sect->sectname, "__restrict") == 0)
                    break;
            }
            
            _key  = [binary subdataWithRange:NSMakeRange(sect->addr, sect->size)];
            break;
        }else
            binary.currentOffset += size;
        
    }

    return _key;
}

@end
