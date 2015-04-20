//
//  FrameworkLoader.h
//  Clutch
//
//  Created by Anton Titkov on 06.04.15.
//
//

#import "Dumper.h"

@interface FrameworkLoader : Dumper

@property (assign) uint32_t ncmds;
@property (assign) uint32_t offset;
@property (assign) uint32_t pages;
@property (assign) uint32_t encryptionInfoCommand;
@property (nonatomic) NSString *binPath;
@property (nonatomic) NSString *dumpPath;
@property (nonatomic) NSString *bID;

- (cpu_type_t)supportedCPUType;

- (BOOL)dumpBinary;

@end
