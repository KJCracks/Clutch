//
//  Framework64Dumper.m
//  Clutch
//
//  Created by Anton Titkov on 02.04.15.
//
//

#import "Framework64Dumper.h"
#import "Device.h"
#import <spawn.h>

@implementation Framework64Dumper

- (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM64;
}

- (BOOL)dumpBinary
{

    ClutchBundle *bundle = [_originalBinary valueForKey:@"_bundle"];

    
    NSString *binaryDumpPath = [_originalBinary.workingPath stringByAppendingPathComponent:_originalBinary.binaryPath.lastPathComponent];
    
    NSString* swappedBinaryPath = _originalBinary.binaryPath, *newSinf = _originalBinary.sinfPath, *newSupp = _originalBinary.suppPath, *newSupf = _originalBinary.supfPath; // default values if we dont need to swap archs
    
    //check if cpusubtype matches
    if (_thinHeader.header.cpusubtype != [Device cpu_subtype]) {
        
        NSString* suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:_thinHeader]];
        
        swappedBinaryPath = [_originalBinary.binaryPath stringByAppendingString:suffix];
        newSinf = [_originalBinary.sinfPath stringByAppendingString:suffix];
        newSupp = [_originalBinary.suppPath stringByAppendingString:suffix];
        newSupf = [_originalBinary.supfPath stringByAppendingString:suffix];
        
        [self swapArch];
    }
    
    NSFileHandle *newFileHandle = [[NSFileHandle alloc]initWithFileDescriptor:fileno(fopen(binaryDumpPath.UTF8String, "r+"))];
    
    [newFileHandle seekToFileOffset:_thinHeader.offset + _thinHeader.size];
    
    struct linkedit_data_command ldid; // LC_CODE_SIGNATURE load header (for resign)
    struct encryption_info_command_64 crypt; // LC_ENCRYPTION_INFO load header (for crypt*)
    struct segment_command_64 __text; // __TEXT segment
    
    struct super_blob *codesignblob; // codesign blob pointer
    struct code_directory directory; // codesign directory index
    
    BOOL foundCrypt = NO, foundSignature = NO, foundStartText = NO;
    
    uint64_t __text_start = 0;
    
    DumperLog(@"64bit dumping: arch %@ offset %u", [Dumper readableArchFromHeader:_thinHeader], _thinHeader.offset);
    
    for (int i = 0; i < _thinHeader.header.ncmds; i++) {
        
        uint32_t cmd = [newFileHandle intAtOffset:newFileHandle.offsetInFile];
        uint32_t size = [newFileHandle intAtOffset:newFileHandle.offsetInFile+sizeof(uint32_t)];
        
        switch (cmd) {
            case LC_CODE_SIGNATURE: {
                [newFileHandle getBytes:&ldid inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct linkedit_data_command))];
                foundSignature = YES;
                
                DumperDebugLog(@"FOUND CODE SIGNATURE: dataoff %u | datasize %u",ldid.dataoff,ldid.datasize);
                
                break;
            }
            case LC_ENCRYPTION_INFO_64: {
                [newFileHandle getBytes:&crypt inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct encryption_info_command_64))];
                foundCrypt = YES;
                
                DumperDebugLog(@"FOUND ENCRYPTION INFO: cryptoff %u | cryptsize %u | cryptid %u",crypt.cryptoff,crypt.cryptsize,crypt.cryptid);
                
                break;
            }
            case LC_SEGMENT_64:
            {
                [newFileHandle getBytes:&__text inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct segment_command_64))];
                
                if (strncmp(__text.segname, "__TEXT", 6) == 0) {
                    foundStartText = YES;
                    DumperDebugLog(@"FOUND %s SEGMENT",__text.segname);
                    __text_start = __text.vmaddr;
                }
                break;
            }
        }
        
        [newFileHandle seekToFileOffset:newFileHandle.offsetInFile + size];
        
        if (foundCrypt && foundSignature && foundStartText)
            break;
    }
    
    // we need to have all of these
    if (!foundCrypt || !foundSignature || !foundStartText) {
        DumperDebugLog(@"dumping binary: some load commands were not found %@ %@ %@",foundCrypt?@"YES":@"NO",foundSignature?@"YES":@"NO",foundStartText?@"YES":@"NO");
        return NO;
    }
    
    NSUInteger begin;

    [newFileHandle seekToFileOffset:_thinHeader.offset + ldid.dataoff];
    
    codesignblob = malloc(ldid.datasize);
    
    [newFileHandle getBytes:codesignblob inRange:NSMakeRange(newFileHandle.offsetInFile, ldid.datasize)];
    
    uint64_t countBlobs = CFSwapInt32(codesignblob->count); // how many indexes?
    
    for (uint64_t index = 0; index < countBlobs; index++) {
        if (CFSwapInt32(codesignblob->index[index].type) == CSSLOT_CODEDIRECTORY) {
            begin = newFileHandle.offsetInFile + CFSwapInt32(codesignblob->index[index].offset);
            [newFileHandle seekToFileOffset:begin];
            [newFileHandle getBytes:&directory inRange:NSMakeRange(begin, sizeof(struct code_directory))];
            break;
        }
    }
    
    free(codesignblob);
    
    uint32_t pages = CFSwapInt32(directory.nCodeSlots); // get the amount of codeslots
    
    if (pages == 0) {
        DumperLog(@"pages == 0");
        return NO;
    }
        
    [newFileHandle closeFile];
    
    [self.originalFileHandle closeFile];
    
    extern char **environ;
    posix_spawnattr_t attr;
    
    pid_t pid;
    
    char *argv[] = {[[NSProcessInfo processInfo].arguments[0] UTF8String],
        "-f",
        swappedBinaryPath.UTF8String,
        binaryDumpPath.UTF8String,
        [NSString stringWithFormat:@"%u",(crypt.cryptsize + crypt.cryptoff)].UTF8String,
        [NSString stringWithFormat:@"%u",pages].UTF8String,
        [NSString stringWithFormat:@"%u",_thinHeader.header.ncmds].UTF8String,
        [NSString stringWithFormat:@"%u",_thinHeader.offset].UTF8String,
        bundle.parentBundle.bundleIdentifier.UTF8String,
        NULL};
    
    posix_spawnattr_init (&attr);
    
    size_t ocount = 0;
    
    cpu_type_t cpu_type = CPU_TYPE_ARM64; //64bit Clutch to dump 64bit framework
    
    posix_spawnattr_setbinpref_np (&attr, 1, &cpu_type, &ocount);
    
    int dumpResult = posix_spawnp(&pid, argv[0], NULL, &attr, argv, environ);
    
    if (dumpResult == 0) {
        DumperDebugLog(@"Child pid: %i", pid);
        if (waitpid(pid, &dumpResult, 0) != -1) {
            DumperDebugLog(@"Success! Child exited with status %i", dumpResult);
        } else {
            perror("waitpid");
        }
    } else {
        ERROR(@"posix_spawn: %s (Error %u)", strerror(dumpResult), dumpResult);
        
    }
    
    if (![swappedBinaryPath isEqualToString:_originalBinary.binaryPath])
        [[NSFileManager defaultManager]removeItemAtPath:swappedBinaryPath error:nil];
    if (![newSinf isEqualToString:_originalBinary.sinfPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSinf error:nil];
    if (![newSupp isEqualToString:_originalBinary.suppPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSupp error:nil];
    if (![newSupf isEqualToString:_originalBinary.supfPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSupf error:nil];
    
    if (dumpResult == 0)
        return YES;
    
    return NO;
}

@end
