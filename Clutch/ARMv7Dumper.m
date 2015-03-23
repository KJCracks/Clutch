//
//  ARMv7Dumper.m
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "ARMv7Dumper.h"

@implementation ARMv7Dumper

+ (cpu_subtype_t)supportedCPUSubtype
{
    return CPU_SUBTYPE_ARM_V7;
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
