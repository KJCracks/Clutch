//
//  ASLR.m
//  Clutch
//
//  Created by Anton Titkov on 14.02.15.
//
//

#import "ASLRDisabler.h"
#import "ClutchPrint.h"
#import "mach_vm.h"
#import <dlfcn.h>
#import <mach-o/fat.h>
#import <mach/mach_init.h>
#import <mach/mach_traps.h>
#import <mach/vm_map.h>

@import MachO.loader;

@implementation ASLRDisabler

+ (mach_vm_address_t)slideForPID:(pid_t)pid error:(NSError *__autoreleasing *)error {
    vm_map_t targetTask = 0;
    kern_return_t kr = 0;
    if (task_for_pid(mach_task_self(), pid, &targetTask)) {
        KJPrint(@"Can't execute task_for_pid! Do you have the right permissions/entitlements?");
        NSDictionary<NSErrorUserInfoKey, NSString *> *userInfo = @{
            NSLocalizedDescriptionKey : @"Failed to execute task_for_pid",
        };
        if (error) {
            *error = [NSError errorWithDomain:NSMachErrorDomain code:-1 userInfo:userInfo];
        }
        return 0;
    }

    vm_address_t iter = 0;
    while (1) {
        struct mach_header mh = {0};
        vm_address_t addr = iter;
        vm_size_t lsize = 0;
        uint32_t depth;
        mach_vm_size_t bytes_read = 0;
        struct vm_region_submap_info_64 info;
        mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;

        if (vm_region_recurse_64(targetTask, &addr, &lsize, &depth, (vm_region_info_t)&info, &count)) {
            break;
        }

        kr = mach_vm_read_overwrite(targetTask,
                                    (mach_vm_address_t)addr,
                                    (mach_vm_size_t)sizeof(struct mach_header),
                                    (mach_vm_address_t)&mh,
                                    &bytes_read);

        if (kr == KERN_SUCCESS && bytes_read == sizeof(struct mach_header)) {
            /* only one image with MH_EXECUTE filetype */
            if ((mh.magic == MH_MAGIC || mh.magic == MH_MAGIC_64) && mh.filetype == MH_EXECUTE) {
                KJDebug(@"Found main binary mach-o image @ %p!", (void *)addr);
                return addr;
            }
        }

        iter = addr + lsize;
    }

    NSDictionary<NSErrorUserInfoKey, NSString *> *userInfo = @{
        NSLocalizedDescriptionKey : @"Should not reach here",
    };
    if (error) {
        *error = [NSError errorWithDomain:NSMachErrorDomain code:-1 userInfo:userInfo];
    }
    return 0;
}

@end
