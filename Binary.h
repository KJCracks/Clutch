//
//  Binary.h
//  Clutch
//
//  Created by Thomas Hedderwick on 04/09/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Application.h"
#import <mach/machine.h>

@interface Binary : NSObject

/* Properties */
@property (nonatomic, strong) NSString *binaryPath;
@property (nonatomic, strong) NSString *temporaryPath;
@property (nonatomic, strong) NSString *targetPath; // path of output file
@property (nonatomic, strong) NSArray *archs;

@property cpu_subtype_t local_cpu_subtype;
@property cpu_type_t local_cpu_type;

@property (strong) Application *application;

/* Methods */
- (void)cleanUp;
- (void)dump;
- (id)initWithApplication:(Application *)app;
- (BOOL)dumpBinary:(FILE *)origin atPath:(NSString *)originPath toFile:(FILE *)target atPath:(NSString *)targetPath withTop:(uint32_t)top error:(NSError **)error;

@end
