//
//  BinaryDumpProtocol.h
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "NSFileHandle+Private.h"
#import "optool.h"
#import <mach/machine.h>

typedef NS_ENUM(NSUInteger, ArchCompatibility) {
    ArchCompatibilityCompatible,
    // ArchCompatibilityStrip,
    ArchCompatibilitySwap,
    ArchCompatibilityNotCompatible,
};

typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);
void sha1(uint8_t *hash, uint8_t *data, size_t size);

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
    unsigned int nCodeSlots; /* number of ordinary (code) hash slots */
    unsigned int codeLimit;
    unsigned char hashSize;
    unsigned char hashType;
    unsigned char spare1;
    unsigned char pageSize;
    unsigned int spare2;
};

@protocol BinaryDumpProtocol <NSObject>

@property (nonatomic, readonly) cpu_type_t supportedCPUType;
@property (nonatomic, readonly) BOOL dumpBinary;

@end

@protocol FrameworkBinaryDumpProtocol <NSObject>

@property (nonatomic, readonly) cpu_type_t supportedCPUType;
@property (nonatomic, readonly) BOOL dumpBinary;

@end
