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
    BOOL _isFAT;
    BOOL _m32;
    BOOL _m64;
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
                
        _dumpOperation = [[BundleDumpOperation alloc]initWithBundle:_bundle];
        
        NSFileHandle *tmpHandle = [[NSFileHandle alloc]initWithFileDescriptor:fileno(fopen(_bundle.executablePath.UTF8String, "r+"))];
        
        NSData *headersData = tmpHandle.availableData;

        [tmpHandle closeFile];
        
        thin_header headers[4];
        uint32_t numHeaders = 0;
        
        headersFromBinary(headers, headersData, &numHeaders);
        
        int m32=0,m64=0;
        for (int i= 0; i<numHeaders; i++) {
            thin_header macho = headers[i];
            
            switch (macho.header.cputype) {
                case MH_MAGIC:
                case MH_CIGAM:
                    m32++;
                    break;
                case MH_MAGIC_64:
                case MH_CIGAM_64:
                    m64++;
                    break;
            }
            
        }
        
        _m32 = m32 > 1;
        _m64 = m64 > 1;
        _isFAT = numHeaders > 1;
        
    }
    
    return self;
}

- (NSString *)binaryPath
{
    return _bundle.executablePath;
}

- (BOOL)isFAT
{
    return _isFAT;
}

- (BOOL)hasARMSlice
{
    return [_bundle.executableArchitectures containsObject:@CPU_TYPE_ARM];
}

- (BOOL)hasARM64Slice
{
    return [_bundle.executableArchitectures containsObject:@CPU_TYPE_ARM64];
}

- (BOOL)hasMultipleARM64Slices
{
    return _m64;
}

- (BOOL)hasMultipleARMSlices
{
    return _m32;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p, executable: %@>",NSStringFromClass([self class]),self,_bundle.executablePath.lastPathComponent];
}

@end


