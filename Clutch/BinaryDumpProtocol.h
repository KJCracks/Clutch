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
    ArchCompatibilityCompatible,
    //ArchCompatibilityStrip,
    ArchCompatibilitySwap,
    ArchCompatibilityNotCompatible,
};

@protocol BinaryDumpProtocol <NSObject>

- (cpu_type_t)supportedCPUType;

- (BOOL)dumpBinaryToURL:(NSURL *)newLocURL;

@end