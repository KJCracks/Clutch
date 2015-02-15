//
//  Dumper.h
//  Clutch
//
//  Created by Anton Titkov on 12.02.15.
//
//

#import <Foundation/Foundation.h>
#import "defines.h"

#define CSSLOT_CODEDIRECTORY 0

#define PT_TRACE_ME 0

struct blob_index {
    unsigned int type;
    unsigned int offset;
};

struct super_blob {
    unsigned int magic;
    unsigned int length;
    unsigned int count;
    struct blob_index index[];
};

struct code_directory {
    unsigned int magic;
    unsigned int length;
    unsigned int version;
    unsigned int flags;
    unsigned int hashOffset;
    unsigned int identOffset;
    unsigned int nSpecialSlots;
    unsigned int nCodeSlots;      /* number of ordinary (code) hash slots */
    unsigned int codeLimit;
    unsigned char hashSize;
    unsigned char hashType;
    unsigned char spare1;
    unsigned char pageSize;
    unsigned int spare2;
};

@class Binary;

@interface Dumper : NSObject

- (instancetype)initWithBinary:(Binary *)binary;

- (NSString *)readableArchFromHeader:(struct thin_header)macho;

- (BOOL)dump32bitFromFileHandle:(NSFileHandle **)fileHandle machHeader:(struct thin_header *)header;
- (BOOL)dump64bitFromFileHandle:(NSFileHandle **)fileHandle machHeader:(struct thin_header *)header;
- (BOOL)removeArchitecture:(struct thin_header*)removeArch;
- (NSString *)stripArch:(cpu_subtype_t)keep_arch;
//- (NSString *)swapArch:(cpu_subtype_t) swaparch;
//- (void)swapBack:(NSString *)path;

@end
