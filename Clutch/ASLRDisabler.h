//
//  ASLR.h
//  Clutch
//
//  Created by Anton Titkov on 14.02.15.
//
//

#import <Foundation/Foundation.h>
#import <mach-o/fat.h>

kern_return_t find_main_binary(pid_t pid, mach_vm_address_t *main_address);

@interface ASLRDisabler : NSObject

@end
