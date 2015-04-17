//
//  Device.h
//  Clutch
//
//  Created by Zorro on 14/11/13.
//  Copyright (c) 2013 AppAddict. All rights reserved.
//
//  Re-tailored for Clutch

#import <UIKit/UIKit.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#import <mach-o/fat.h>

#import "BinaryDumpProtocol.h"

@interface Device : NSObject

+ (cpu_type_t)cpu_type;
+ (cpu_subtype_t)cpu_subtype;

@end
