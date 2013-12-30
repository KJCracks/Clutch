//
//  CABinary.h
//  CrackAddict
//
//  Created by Zorro on 13/11/13.
//  Copyright (c) 2013 AppAddict. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "out.h"
#import "Prefs.h"
#include <mach/mach.h>
#include <mach/vm_region.h>
#include <mach/vm_map.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach-o/arch.h>

#define CPUTYPE_32 0xc000000
#define CPUTYPE_64 0xc000001

NSString* sinf_file;
NSString* supp_file;
NSString* supf_file;

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

enum CAArch {
    CAArchARMv6 = 6,
    CAArchARMv7 = 9,
    CAArchARMv7s = 11,
    CAArchARM64v8 = 8,
    CAArchUnknown = -1
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


@interface CABinary : NSObject
{
    @public
       BOOL overdriveEnabled;
}
- (id)initWithBinary:(NSString *)path;
- (BOOL)crackBinaryToFile:(NSString *)path error:(NSError **)error;

@end
