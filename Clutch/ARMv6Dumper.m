//
//  ARMv6Dumper.m
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "ARMv6Dumper.h"

@implementation ARMv6Dumper

+ (cpu_subtype_t)supportedCPUSubtype
{
    return CPU_SUBTYPE_ARM_V6;
}

+ (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM;
}

- (BOOL)dumpBinaryAtURL:(NSURL *)origLocURL toURL:(NSURL *)newLocURL
{
    
    return NO;
}

@end
