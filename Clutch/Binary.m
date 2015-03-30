//
//  Binary.m
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "Binary.h"
#import "ClutchBundle.h"
#import "Dumper_old.h"

#include <mach-o/fat.h>

@interface Binary ()
{
    ClutchBundle *_bundle;
}
@end

@implementation Binary

- (NSString *)workingPath
{
    return [_bundle.workingPath stringByAppendingPathComponent:_bundle.bundleIdentifier];
}

- (instancetype)initWithBundle:(ClutchBundle *)path
{
    if (self = [super init]) {
        _bundle = path;
        
        _sinfPath = [_bundle pathForResource:_bundle.executablePath.lastPathComponent ofType:@"sinf" inDirectory:@"SC_Info"];
        _supfPath = [_bundle pathForResource:_bundle.executablePath.lastPathComponent ofType:@"supf" inDirectory:@"SC_Info"];
        _suppPath = [_bundle pathForResource:_bundle.executablePath.lastPathComponent ofType:@"supp" inDirectory:@"SC_Info"];
        
        _binaryFile = fopen([self.binaryPath UTF8String], "r+");
        
        _dumpOperation = [[BundleDumpOperation alloc]initWithBundle:_bundle];
    }
    
    return self;
}

- (NSString *)binaryPath
{
    return _bundle.executablePath;
}

- (BOOL)hasARMSlice
{
    return [_bundle.executableArchitectures containsObject:@CPU_TYPE_ARM];
}

- (BOOL)hasARM64Slice
{
    return [_bundle.executableArchitectures containsObject:@CPU_TYPE_ARM64];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, binary: %@>",NSStringFromClass([self class]),self,_bundle.executablePath.lastPathComponent];
}

@end


