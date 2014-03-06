//
//  Constants.h
//  Clutch
//
//  Created by Zorro on 30.12.13.
//
//

#import <mach/mach.h>
#import <mach/mach_traps.h>
#import <mach/vm_map.h>
#import <mach/vm_region.h>

#import <mach-o/arch.h>
#import <mach-o/dyld.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>

#import <dlfcn.h>
#import <unistd.h>
#import <spawn.h>

/*
 * Configuration
 */

#define CLUTCH_TITLE "Clutch"
#define CLUTCH_VERSION "1.4.3"
#define CLUTCH_RELEASE "git-2"
#define CLUTCH_BUILD 14302
#define CLUTCH_DEV 0 //1


void sha1(uint8_t *hash, uint8_t *data, size_t size);
typedef int (*ptrace_ptr_t)(int _request, pid_t _pid, caddr_t _addr, int _data);

char buffer[4096];

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

struct BlobIndex64 {
	uint64_t type;
	uint64_t offset;
};

struct Blob64 {
	uint64_t magic;
	uint64_t length;
};

struct SuperBlob64 {
	struct Blob64 blob;
	uint64_t count;
	struct BlobIndex64 index[];
};

struct CodeDirectory64 {
	struct Blob64 blob;
	uint64_t version;
	uint64_t flags;
	uint64_t hashOffset;
	uint64_t identOffset;
	uint64_t nSpecialSlots;
	uint64_t nCodeSlots;
	uint64_t codeLimit;
	uint16_t hashSize;
	uint16_t hashType;
	uint16_t spare1;
	uint16_t pageSize;
	uint64_t spare2;
    
};

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

#define OVERDRIVE_DYLIB_CURRENT_VER 0x20000
#define OVERDRIVE_DYLIB_COMPATIBILITY_VERSION 0x20000

#define MH_PIE 0x200000

#define CSSLOT_CODEDIRECTORY 0

#define PT_TRACE_ME 0

#ifdef __LP64__
typedef vm_region_basic_info_data_64_t vm_region_basic_info_data;
typedef vm_region_info_64_t vm_region_info;
#define VM_REGION_BASIC_INFO_COUNT_UNIV VM_REGION_BASIC_INFO_COUNT_64

#else

typedef vm_region_basic_info_data_t vm_region_basic_info_data;
typedef vm_region_info_t vm_region_info;
#define VM_REGION_BASIC_INFO_COUNT_UNIV VM_REGION_BASIC_INFO_COUNT_64
#endif
