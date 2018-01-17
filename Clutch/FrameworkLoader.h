//
//  FrameworkLoader.h
//  Clutch
//
//  Created by Anton Titkov on 06.04.15.
//
//

#import "Dumper.h"

@interface FrameworkLoader : Dumper

@property (nonatomic, assign) uint32_t ncmds;
@property (nonatomic, assign) uint32_t offset;
@property (nonatomic, assign) uint32_t pages;
@property (nonatomic, assign) uint32_t dumpSize;
@property (nonatomic, assign) uint32_t hashOffset;
@property (nonatomic, assign) uint32_t cryptoff;
@property (nonatomic, assign) uint32_t cryptsize;
@property (nonatomic, assign) uint32_t cryptlc_offset;
@property (nonatomic, assign) uint32_t codesign_begin;
@property (nonatomic, assign) BOOL arm64;
@property (nonatomic, retain) NSString *binPath;
@property (nonatomic, retain) NSString *dumpPath;
@property (nonatomic, retain) NSString *bID;

- (cpu_type_t)supportedCPUType;

- (BOOL)dumpBinary;

@end
