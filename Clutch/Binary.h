//
//  Binary.h
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import <Foundation/Foundation.h>
#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <mach-o/arch.h>

@interface Binary : NSObject

@property (readonly) NSString *binaryPath;

- (instancetype)initWithBundle:(NSBundle *)bundle;

@end
