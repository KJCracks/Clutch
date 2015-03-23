//
//  ASLR.m
//  Clutch
//
//  Created by Anton Titkov on 14.02.15.
//
//

#import "ASLRDisabler.h"
#import <dlfcn.h>
#import <mach-o/fat.h>
#import <mach/mach_traps.h>
#import <mach/mach_init.h>
#import <mach/vm_map.h>
#import "mach_vm.h"

@import MachO.loader;

static kern_return_t readmem(mach_vm_offset_t *buffer, mach_vm_address_t address, mach_vm_size_t size, pid_t pid, vm_region_basic_info_data_64_t *info);

kern_return_t
find_main_binary(pid_t pid, mach_vm_address_t *main_address)
{
    vm_map_t targetTask = 0;
    kern_return_t kr = 0;
    if (task_for_pid(mach_task_self(), pid, &targetTask))
    {
        NSLog(@"[ERROR] Can't execute task_for_pid! Do you have the right permissions/entitlements?\n");
        return KERN_FAILURE;
    }
    
    vm_address_t iter = 0;
    while (1)
    {
        struct mach_header mh = {0};
        vm_address_t addr = iter;
        vm_size_t lsize = 0;
        uint32_t depth;
        mach_vm_size_t bytes_read = 0;
        struct vm_region_submap_info_64 info;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
        if (vm_region_recurse_64(targetTask, &addr, &lsize, &depth, (vm_region_info_t)&info, &count))
        {
            break;
        }
        kr = mach_vm_read_overwrite(targetTask, (mach_vm_address_t)addr, (mach_vm_size_t)sizeof(struct mach_header), (mach_vm_address_t)&mh, &bytes_read);
        if (kr == KERN_SUCCESS && bytes_read == sizeof(struct mach_header))
        {
            /* only one image with MH_EXECUTE filetype */
            if ((mh.magic == MH_MAGIC || mh.magic == MH_MAGIC_64) && mh.filetype == MH_EXECUTE)
            {
#if DEBUG
                NSLog(@"Found main binary mach-o image @ %p!\n", (void*)addr);
#endif
                *main_address = addr;
                break;
            }
        }
        iter = addr + lsize;
    }
    return KERN_SUCCESS;
}

/*
 * we need to find the binary file size
 * which is taken from the filesize field of each segment command
 * and not the vmsize (because of alignment)
 * if we dump using vmaddresses, we will get the alignment space into the dumped
 * binary and get into problems :-)
 */
int64_t
get_image_size(mach_vm_address_t address, pid_t pid, uint64_t *vmaddr_slide)
{
    vm_region_basic_info_data_64_t region_info = {0};
    // allocate a buffer to read the header info
    // NOTE: this is not exactly correct since the 64bit version has an extra 4 bytes
    // but this will work for this purpose so no need for more complexity!
    struct mach_header header = {0};
    if (readmem((mach_vm_offset_t*)&header, address, sizeof(struct mach_header), pid, &region_info))
    {
        NSLog(@"Can't read header!");
        return -1;
    }
    
    if (header.magic != MH_MAGIC && header.magic != MH_MAGIC_64)
    {
        printf("[ERROR] Target is not a mach-o binary!\n");
        return -1;
    }
    
    int64_t imagefilesize = -1;
    /* read the load commands */
    uint8_t *loadcmds = (uint8_t*)malloc(header.sizeofcmds);
    uint16_t mach_header_size = sizeof(struct mach_header);
    if (header.magic == MH_MAGIC_64)
    {
        mach_header_size = sizeof(struct mach_header_64);
    }
    if (readmem((mach_vm_offset_t*)loadcmds, address+mach_header_size, header.sizeofcmds, pid, &region_info))
    {
        NSLog(@"Can't read load commands");
        return -1;
    }
    
    /* process and retrieve address and size of linkedit */
    uint8_t *loadCmdAddress = 0;
    loadCmdAddress = (uint8_t*)loadcmds;
    struct load_command *loadCommand    = NULL;
    struct segment_command *segCmd      = NULL;
    struct segment_command_64 *segCmd64 = NULL;
    for (uint32_t i = 0; i < header.ncmds; i++)
    {
        loadCommand = (struct load_command*)loadCmdAddress;
        if (loadCommand->cmd == LC_SEGMENT)
        {
            segCmd = (struct segment_command*)loadCmdAddress;
            if (strncmp(segCmd->segname, "__PAGEZERO", 16) != 0)
            {
                if (strncmp(segCmd->segname, "__TEXT", 16) == 0)
                {
                    *vmaddr_slide = address - segCmd->vmaddr;
                }
                imagefilesize += segCmd->filesize;
            }
        }
        else if (loadCommand->cmd == LC_SEGMENT_64)
        {
            segCmd64 = (struct segment_command_64*)loadCmdAddress;
            if (strncmp(segCmd64->segname, "__PAGEZERO", 16) != 0)
            {
                if (strncmp(segCmd64->segname, "__TEXT", 16) == 0)
                {
                    *vmaddr_slide = address - segCmd64->vmaddr;
                }
                imagefilesize += segCmd64->filesize;
            }
        }
        // advance to next command
        loadCmdAddress += loadCommand->cmdsize;
    }
    free(loadcmds);
    return imagefilesize;
}

static kern_return_t
readmem(mach_vm_offset_t *buffer, mach_vm_address_t address, mach_vm_size_t size, pid_t pid, vm_region_basic_info_data_64_t *info)
{
    // get task for pid
    vm_map_t port;
    
    kern_return_t kr;
    //#if DEBUG
    //    printf("[DEBUG] Readmem of address %llx to buffer %llx with size %llx\n", address, buffer, size);
    //#endif
    if (task_for_pid(mach_task_self(), pid, &port))
    {
        fprintf(stderr, "[ERROR] Can't execute task_for_pid! Do you have the right permissions/entitlements?\n");
        return KERN_FAILURE;
    }
    
    mach_msg_type_number_t info_cnt = sizeof (vm_region_basic_info_data_64_t);
    mach_port_t object_name;
    mach_vm_size_t size_info;
    mach_vm_address_t address_info = address;
    kr = mach_vm_region(port, &address_info, &size_info, VM_REGION_BASIC_INFO_64, (vm_region_info_t)info, &info_cnt, &object_name);
    if (kr)
    {
        fprintf(stderr, "[ERROR] mach_vm_region failed with error %d\n", (int)kr);
        return KERN_FAILURE;
    }
    
    /* read memory - vm_read_overwrite because we supply the buffer */
    mach_vm_size_t nread;
    kr = mach_vm_read_overwrite(port, address, size, (mach_vm_address_t)buffer, &nread);
    if (kr)
    {
        fprintf(stderr, "[ERROR] vm_read failed! %d\n", kr);
        return KERN_FAILURE;
    }
    else if (nread != size)
    {
        fprintf(stderr, "[ERROR] vm_read failed! requested size: 0x%llx read: 0x%llx\n", size, nread);
        return KERN_FAILURE;
    }
    return KERN_SUCCESS;
}

@implementation ASLRDisabler


@end
