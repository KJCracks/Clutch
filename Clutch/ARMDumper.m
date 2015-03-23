//
//  ARMDumper.m
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "ARMDumper.h"

@implementation ARMDumper

- (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM;
}

- (BOOL)dumpBinaryToURL:(NSURL *)newLocURL {
    
    
    
    return NO;
}

@end
