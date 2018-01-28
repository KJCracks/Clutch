//
//  Device.h
//  Clutch
//
//  Created by Zorro on 14/11/13.
//  Copyright (c) 2013 AppAddict. All rights reserved.
//
//  Re-tailored for Clutch

#import "BinaryDumpProtocol.h"
#import <UIKit/UIKit.h>
#import <mach-o/fat.h>
#include <sys/stat.h>
#include <sys/sysctl.h>

NS_ASSUME_NONNULL_BEGIN

@interface Device : NSObject

+ (cpu_type_t)cpu_type;
+ (cpu_subtype_t)cpu_subtype;

@end

NS_ASSUME_NONNULL_END
