//
//  ASLR.h
//  Clutch
//
//  Created by Anton Titkov on 14.02.15.
//
//

#import <Foundation/Foundation.h>
#import <mach-o/fat.h>

@interface ASLRDisabler : NSObject

+ (mach_vm_address_t)slideForPID:(pid_t)pid error:(NSError **)error;

@end
