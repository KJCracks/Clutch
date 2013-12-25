#import "Configuration.h"
#import "sha1.h"
#import <dlfcn.h>
#import <unistd.h>
#import <mach/mach_traps.h>
#import <mach/mach.h>
#import "out.h"
#import "crack.h"
#include <spawn.h>
#include <mach-o/dyld.h>
#include <dlfcn.h>

#define OVERDRIVE_DYLIB_PATH "@executable_path/overdrive.dylib"
#define OVERDRIVE_DYLIB_CURRENT_VER 0x20000
#define OVERDRIVE_DYLIB_COMPATIBILITY_VERSION 0x20000

#define LC_CODE_SIGNATURE  0x1d
#define LC_ENCRYPTION_INFO 0x21
#define LC_SEGMENT 0x1

#define MH_PIE 0x200000

#define CSSLOT_CODEDIRECTORY 0

#define PT_TRACE_ME 0


void sha1(uint8_t *hash, uint8_t *data, size_t size);
BOOL dump_binary_64(FILE *origin, FILE *target, uint32_t top, NSString *originPath, NSString *finalPath);
BOOL dump_binary_32(FILE *origin, FILE *target, uint32_t top, NSString *originPath, NSString *finalPath);


typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);

extern kern_return_t mach_vm_region
(
 vm_map_t target_task,
 mach_vm_address_t *address,
 mach_vm_size_t *size,
 vm_region_flavor_t flavor,
 vm_region_info_t info,
 mach_msg_type_number_t *infoCnt,
 mach_port_t *object_name
 );

extern kern_return_t mach_vm_read_overwrite
(
 vm_map_t target_task,
 mach_vm_address_t address,
 mach_vm_size_t size,
 mach_vm_address_t data,
 mach_vm_size_t *outsize
 );

extern kern_return_t mach_vm_protect
(
 vm_map_t target_task,
 mach_vm_address_t address,
 mach_vm_size_t size,
 boolean_t set_maximum,
 vm_prot_t new_protection
 );

extern kern_return_t mach_vm_write
(
 vm_map_t target_task,
 mach_vm_address_t address,
 vm_offset_t data,
 mach_msg_type_number_t dataCnt
 );


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