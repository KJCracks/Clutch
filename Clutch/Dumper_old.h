//
//  Dumper.h
//  Clutch
//
//  Created by Anton Titkov on 12.02.15.
//
//

#import <Foundation/Foundation.h>
#import "optool-defines.h"
#import "BinaryDumpProtocol.h"

@class Binary;

@interface Dumper_old : NSObject

- (instancetype)initWithBinary:(Binary *)binary NS_DESIGNATED_INITIALIZER;

- (NSString *)readableArchFromHeader:(thin_header)macho;

- (BOOL)dump32bitFromFileHandle:(NSFileHandle **)fileHandle machHeader:(thin_header *)header;
- (BOOL)dump64bitFromFileHandle:(NSFileHandle **)fileHandle machHeader:(thin_header *)header;
- (BOOL)removeArchitecture:(thin_header*)removeArch;
- (NSString *)stripArch:(cpu_subtype_t)keep_arch;
//- (NSString *)swapArch:(cpu_subtype_t) swaparch;
//- (void)swapBack:(NSString *)path;

@end
