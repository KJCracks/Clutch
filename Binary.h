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

/* Structs */
struct BlobIndex {
    uint32_t type;
    uint32_t offset;
};

struct Blob {
    uint32_t magic;
    uint32_t length;
};

struct SuperBlob {
    struct Blob blob;
    uint32_t count;
    struct BlobIndex index[];
};

struct CodeDirectory {
    struct Blob blob;
    uint32_t version;
    uint32_t flags;
    uint32_t hashOffset;
    uint32_t identOffset;
    uint32_t nSpecialslots;
    uint32_t nCodeSlots;
    uint32_t codeLimit;
    uint8_t hashSize;
    uint8_t hashType;
    uint8_t spare1;
    uint8_t pageSize;
    uint32_t spare2;
};

typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);

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
