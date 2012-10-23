#import "Configuration.h"
#import "sha1.h"
#import <dlfcn.h>
#import <unistd.h>
#import <mach/mach_traps.h>
#import <mach/mach.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>
#import "out.h"
#import "crack.h"

#define OVERDRIVE_DYLIB_PATH "@executable_path/overdrive.dylib"
#define OVERDRIVE_DYLIB_CURRENT_VER 0x20000
#define OVERDRIVE_DYLIB_COMPATIBILITY_VERSION 0x20000

void sha1(uint8_t *hash, uint8_t *data, size_t size);
BOOL dump_binary(FILE *origin, FILE *target, uint32_t top, NSString *originPath);

#define LC_CODE_SIGNATURE  0x1d
#define LC_ENCRYPTION_INFO 0x21

#define LC_SEGMENT 0x1

#define MH_PIE 0x200000

#define CSSLOT_CODEDIRECTORY 0

#define PT_TRACE_ME 0
typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);

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
	uint32_t nSpecialSlots;
	uint32_t nCodeSlots;
	uint32_t codeLimit;
	uint8_t hashSize;
	uint8_t hashType;
	uint8_t spare1;
	uint8_t pageSize;
	uint32_t spare2;
};