//
//  ASLR.h
//  Clutch
//
//  Created by Anton Titkov on 14.02.15.
//
//

#import <mach-o/fat.h>

NS_ASSUME_NONNULL_BEGIN

@interface ASLRDisabler : NSObject

+ (mach_vm_address_t)slideForPID:(pid_t)pid error:(NSError *__autoreleasing *)error;

@end

NS_ASSUME_NONNULL_END
