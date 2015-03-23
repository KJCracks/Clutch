//
//  Dumper.m
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "Dumper.h"
#import "Device.h"

@implementation Dumper

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static id shared = nil;
    dispatch_once(&pred, ^{
        shared = [self new];
    });
    return shared;
}

- (BOOL)canDumpArchForHeader:(thin_header)header
{
    return NO;
}

- (cpu_type_t)supportedCPUType
{
#warning not implemented on purpose
    return NULL;
}

- (cpu_subtype_t)supportedCPUSubtype
{
#warning not implemented on purpose
    return NULL;
}

- (BOOL)dumpBinaryAtURL:(NSURL *)origLocURL toURL:(NSURL *)newLocURL
{
#warning not implemented on purpose
    return NO;
}

- (ArchCompatibility)compatibilityModeWithCurrentDevice
{
    cpu_type_t cputype = self.supportedCPUType;
    cpu_subtype_t cpusubtype = self.supportedCPUSubtype;
    
    if ((cpusubtype != Device.cpu_subtype) || (cputype != Device.cpu_type))
    {
        //not same, definitely swap or no
        if ((Device.cpu_type == CPU_TYPE_ARM) && (cpusubtype > Device.cpu_subtype))
        {
            NSLog(@"Can't crack 32bit arch %d on %d! not compatible", cpusubtype, Device.cpu_subtype);
            return NOT_COMPATIBLE;
        }
        else if (cputype == CPU_TYPE_ARM64)
        {
            if ((Device.cpu_type == CPU_TYPE_ARM64) && (cpusubtype > Device.cpu_subtype))
            {
                NSLog(@"Can't crack 64bit arch %d on %d! skipping", cpusubtype, Device.cpu_subtype);
                return NOT_COMPATIBLE;
            }
            else if (Device.cpu_type == CPU_TYPE_ARM)
            {
                NSLog(@"Can't crack 64bit arch on 32bit device! skipping");
                return NOT_COMPATIBLE;
            }
        }
        
        return COMPATIBLE_SWAP;
    }
    
    return COMPATIBLE;

}

@end
