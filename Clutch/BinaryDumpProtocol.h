//
//  BinaryDumpProtocol.h
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import <Foundation/Foundation.h>
#import <mach/machine.h>
#import "optool.h"

typedef NS_ENUM(NSUInteger, ArchCompatibility) {
    COMPATIBLE,
    //COMPATIBLE_STRIP,
    COMPATIBLE_SWAP,
    NOT_COMPATIBLE,
};

@protocol BinaryDumpProtocol <NSObject>

+ (BOOL)canDumpArchForHeader:(thin_header *)header;
+ (cpu_type_t)supportedCPUType;
+ (cpu_subtype_t)supportedCPUSubtype;

- (BOOL)dumpBinaryAtURL:(NSURL *)origLocURL toURL:(NSURL *)newLocURL;

@end