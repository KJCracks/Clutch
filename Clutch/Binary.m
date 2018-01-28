//
//  Binary.m
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "Binary.h"
#import "ClutchBundle.h"

#import "ClutchPrint.h"
#import "NSFileHandle+Private.h"
#import "optool.h"
#include <mach-o/fat.h>

@interface Binary () {
    ClutchBundle *_bundle;
    BOOL _isFAT;
    BOOL _m32;
    BOOL _m64;
}
@end

@implementation Binary

- (NSString *)workingPath {
    return [_bundle.workingPath stringByAppendingPathComponent:_bundle.bundleIdentifier];
}

- (nullable instancetype)init {
    return [self initWithBundle:nil];
}

- (nullable instancetype)initWithBundle:(nullable ClutchBundle *)path {
    if (!path) {
        return nil;
    }

    if (self = [super init]) {
        _bundle = path;

        KJDebug(@"######## bundle URL %@", _bundle.bundleContainerURL);
        if ([(_bundle.bundleContainerURL).path hasSuffix:@"Frameworks"]) {
            _frameworksPath = (_bundle.bundleContainerURL).path;
        }

        // perm. fix

        NSDictionary *ownershipInfo = @{NSFileOwnerAccountName : @"mobile", NSFileGroupOwnerAccountName : @"mobile"};

        [[NSFileManager defaultManager] setAttributes:ownershipInfo ofItemAtPath:self.binaryPath error:nil];

        _sinfPath =
            [_bundle pathForResource:_bundle.executablePath.lastPathComponent ofType:@"sinf" inDirectory:@"SC_Info"];
        _supfPath =
            [_bundle pathForResource:_bundle.executablePath.lastPathComponent ofType:@"supf" inDirectory:@"SC_Info"];
        _suppPath =
            [_bundle pathForResource:_bundle.executablePath.lastPathComponent ofType:@"supp" inDirectory:@"SC_Info"];

        _dumpOperation = [[BundleDumpOperation alloc] initWithBundle:_bundle];

        NSFileHandle *tmpHandle =
            [[NSFileHandle alloc] initWithFileDescriptor:fileno(fopen(_bundle.executablePath.UTF8String, "r+"))
                                          closeOnDealloc:YES];

        NSData *headersData = tmpHandle.availableData;

        thin_header headers[4];
        uint32_t numHeaders = 0;

        headersFromBinary(headers, headersData, &numHeaders);

        int m32 = 0, m64 = 0;
        for (unsigned int i = 0; i < numHeaders; i++) {
            thin_header macho = headers[i];

            switch (macho.header.cputype) {
                case CPU_TYPE_ARM:
                    m32++;
                    break;
                case CPU_TYPE_ARM64:
                    m64++;
                    break;
            }
        }

        _m32 = m32 > 1;
        _m64 = m64 > 1;
        _isFAT = numHeaders > 1;

        _hasRestrictedSegment = NO;

        struct thin_header macho = headers[0];

        unsigned long long size = [tmpHandle seekToEndOfFile];

        [tmpHandle seekToFileOffset:macho.offset + macho.size];

        for (unsigned int i = 0; i < macho.header.ncmds; i++) {
            if (tmpHandle.offsetInFile >= size ||
                tmpHandle.offsetInFile > macho.header.sizeofcmds + macho.size + macho.offset)
                break;

            uint32_t cmd = [tmpHandle unsignedInt32Atoffset:tmpHandle.offsetInFile];
            uint32_t size_ = [tmpHandle unsignedInt32Atoffset:tmpHandle.offsetInFile + sizeof(uint32_t)];

            struct segment_command *command;

            command = malloc(sizeof(struct segment_command));

            [tmpHandle getBytes:command
                        inRange:NSMakeRange((NSUInteger)(tmpHandle.offsetInFile), sizeof(struct segment_command))];

            if (((cmd == LC_SEGMENT) || (cmd == LC_SEGMENT_64)) && (strcmp(command->segname, "__RESTRICT") == 0)) {
                _hasRestrictedSegment = YES;
                break;
            } else
                [tmpHandle seekToFileOffset:tmpHandle.offsetInFile + size_];

            free(command);
        }

        [tmpHandle closeFile];
    }

    return self;
}

- (NSString *)binaryPath {
    NSString *path = [_bundle.executablePath copy];

    if ([path hasPrefix:@"/var/mobile"]) {
        path = [@"/private" stringByAppendingString:path];
    }

    return path;
}

- (BOOL)isFAT {
    return _isFAT;
}

- (BOOL)hasARMSlice {
    return [_bundle.executableArchitectures containsObject:@CPU_TYPE_ARM];
}

- (BOOL)hasARM64Slice {
    return [_bundle.executableArchitectures containsObject:@CPU_TYPE_ARM64];
}

- (BOOL)hasMultipleARM64Slices {
    return _m64;
}

- (BOOL)hasMultipleARMSlices {
    return _m32;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@>", _bundle.executablePath.lastPathComponent];
}

@end
