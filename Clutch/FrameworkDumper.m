//
//  FrameworkDumper.m
//  Clutch
//
//  Created by Anton Titkov on 02.04.15.
//
//

#import "FrameworkDumper.h"
#import "Device.h"
#import <spawn.h>

@implementation FrameworkDumper

- (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM;
}

- (BOOL)dumpBinary
{
    
    ClutchBundle *bundle = [_originalBinary valueForKey:@"_bundle"];
    
    NSString *binaryDumpPath = [_originalBinary.workingPath stringByAppendingPathComponent:_originalBinary.binaryPath.lastPathComponent];

    NSString* swappedBinaryPath = _originalBinary.binaryPath, *newSinf = _originalBinary.sinfPath, *newSupp = _originalBinary.suppPath; // default values if we dont need to swap archs
    
    //check if cpusubtype matches
    if (_thinHeader.header.cpusubtype != [Device cpu_subtype]) {
        
        NSString* suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:_thinHeader]];
        
        swappedBinaryPath = [_originalBinary.binaryPath stringByAppendingString:suffix];
        newSinf = [_originalBinary.sinfPath.stringByDeletingPathExtension stringByAppendingString:[suffix stringByAppendingPathExtension:_originalBinary.sinfPath.pathExtension]];
        newSupp = [_originalBinary.suppPath.stringByDeletingPathExtension stringByAppendingString:[suffix stringByAppendingPathExtension:_originalBinary.suppPath.pathExtension]];
        
        [self swapArch];
        
    }
    
    NSFileHandle *newFileHandle = [[NSFileHandle alloc]initWithFileDescriptor:fileno(fopen(binaryDumpPath.UTF8String, "r+"))];
    
    [newFileHandle seekToFileOffset:_thinHeader.offset + _thinHeader.size];
    
    struct linkedit_data_command ldid; // LC_CODE_SIGNATURE load header (for resign)
    struct encryption_info_command crypt; // LC_ENCRYPTION_INFO load header (for crypt*)
    struct segment_command __text; // __TEXT segment
    
    struct super_blob *codesignblob; // codesign blob pointer
    struct code_directory directory; // codesign directory index
    
    BOOL foundCrypt = NO, foundSignature = NO, foundStartText = NO;
    
    uint64_t __text_start = 0;
    
    DumperLog(@"32bit dumping: arch %@ offset %u", [Dumper readableArchFromHeader:_thinHeader], _thinHeader.offset);
    
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
            case LC_ENCRYPTION_INFO: {
                [newFileHandle getBytes:&crypt inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct encryption_info_command))];
                foundCrypt = YES;
                
                DumperDebugLog(@"FOUND ENCRYPTION INFO: cryptoff %u | cryptsize %u | cryptid %u",crypt.cryptoff,crypt.cryptsize,crypt.cryptid);
                
                break;
            }
            case LC_SEGMENT:
            {
                [newFileHandle getBytes:&__text inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct segment_command))];
                
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
    
    NSLog(@"starting to ldid");
    
    NSUInteger begin;
    
    //seek to ldid offset
    
    codesignblob = malloc(ldid.datasize);
    
    [newFileHandle seekToFileOffset:_thinHeader.offset + ldid.dataoff];
    [newFileHandle getBytes:codesignblob inRange:NSMakeRange(newFileHandle.offsetInFile, ldid.datasize)];
    NSLog(@"hello it's me");
    
    uint32_t countBlobs = CFSwapInt32(codesignblob->count); // how many indexes?
    
    for (uint32_t index = 0; index < countBlobs; index++) { // is this the code directory?
        if (CFSwapInt32(codesignblob->index[index].type) == CSSLOT_CODEDIRECTORY) {
            // we'll find the hash metadata in here
            DumperDebugLog(@"%u %u %u", _thinHeader.offset, ldid.dataoff, codesignblob->index[index].offset);
            begin = _thinHeader.offset + ldid.dataoff + CFSwapInt32(codesignblob->index[index].offset); // store the top of the codesign directory blob
            [newFileHandle getBytes:&directory inRange:NSMakeRange(begin, sizeof(struct code_directory))]; //read the blob from its beginning
            DumperDebugLog(@"Found CSSLOT_CODEDIRECTORY");
            break; //break (we don't need anything from this the superblob anymore)
        }
    }
    
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
    
    /* fmwk.binPath = arguments[2];
     fmwk.dumpPath = arguments[3];
     fmwk.dumpSize = [arguments[4]intValue];
     fmwk.pages = [arguments[5]intValue];
     fmwk.ncmds = [arguments[6]intValue];
     fmwk.offset = [arguments[7]intValue];
     fmwk.bID = arguments[8];
     fmwk.hashOffset = [arguments[9] intValue];
     fmwk.codesign_begin = [arguments[10] intValue];
     */
    
    NSUUID* workingUUID = [NSUUID new];
    NSString* workingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"clutch" stringByAppendingPathComponent:workingUUID.UUIDString]];
    
    while ([[NSFileManager defaultManager] fileExistsAtPath:workingPath]) {
        workingUUID = [NSUUID new];
        workingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"clutch" stringByAppendingPathComponent:workingUUID.UUIDString]];
    }
    
    [[NSFileManager defaultManager] createDirectoryAtPath:workingPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    if (![[NSFileManager defaultManager] createSymbolicLinkAtPath:[workingPath stringByAppendingPathComponent:@"clutch"] withDestinationPath:[NSProcessInfo processInfo].arguments[0] error:nil]) {
        ERROR(@"Failed to create symbolic link to %@", workingPath);
        return NO;
    }
    
    if (_originalBinary.frameworksPath == nil) {
        ERROR(@"Could not find Frameworks path to create symbolic link to");
        return NO;
    }
    
    [[NSFileManager defaultManager] createSymbolicLinkAtPath:[workingPath stringByAppendingPathComponent:@"Frameworks"] withDestinationPath:_originalBinary.frameworksPath error:nil];
    
    const char *argv[] = {[[NSProcessInfo processInfo].arguments[0] UTF8String],
        "-f",
        swappedBinaryPath.UTF8String,
        binaryDumpPath.UTF8String,
        [NSString stringWithFormat:@"%u",(crypt.cryptsize + crypt.cryptoff)].UTF8String,
        [NSString stringWithFormat:@"%u",pages].UTF8String,
        [NSString stringWithFormat:@"%u",_thinHeader.header.ncmds].UTF8String,
        [NSString stringWithFormat:@"%u",_thinHeader.offset].UTF8String,
        bundle.parentBundle.bundleIdentifier.UTF8String,
        [NSString stringWithFormat:@"%u",CFSwapInt32(directory.hashOffset)].UTF8String,
        [NSString stringWithFormat:@"%u",begin].UTF8String,
        NULL};
    
    
    NSLog(@"%s %s %s %s %s %s %s %s %s %s %s", [[NSProcessInfo processInfo].arguments[0] UTF8String],
          "-f",
          swappedBinaryPath.UTF8String,
          binaryDumpPath.UTF8String,
          [NSString stringWithFormat:@"%u",(crypt.cryptsize + crypt.cryptoff)].UTF8String,
          [NSString stringWithFormat:@"%u",pages].UTF8String,
          [NSString stringWithFormat:@"%u",_thinHeader.header.ncmds].UTF8String,
          [NSString stringWithFormat:@"%u",_thinHeader.offset].UTF8String,
          
          bundle.parentBundle.bundleIdentifier.UTF8String,
          [NSString stringWithFormat:@"%u",CFSwapInt32(directory.hashOffset)].UTF8String,
          [NSString stringWithFormat:@"%u",begin].UTF8String);

    DumperDebugLog(@"hello potato posix_spawn %@", [[NSString alloc] initWithUTF8String:argv]);

    
    posix_spawnattr_init (&attr);
    
    size_t ocount = 0;
    
    cpu_type_t cpu_type = CPU_TYPE_ARM;
    
    posix_spawnattr_setbinpref_np (&attr, 1, &cpu_type, &ocount);
    
    int dumpResult = posix_spawnp(&pid, argv[0], NULL, &attr, (char* const*)argv, environ);
    
    if (dumpResult == 0) {
        DumperDebugLog(@"Child pid: %u", pid);
        if (waitpid(pid, &dumpResult, 0) != -1) {
            DumperDebugLog(@"Child exited with status %u", dumpResult);
        } else {
            perror("waitpid");
        }
    } else {
        DumperDebugLog(@"posix_spawn: %s", strerror(dumpResult));
    }
    
    
    if (![swappedBinaryPath isEqualToString:_originalBinary.binaryPath])
        [[NSFileManager defaultManager]removeItemAtPath:swappedBinaryPath error:nil];
    if (![newSinf isEqualToString:_originalBinary.sinfPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSinf error:nil];
    if (![newSupp isEqualToString:_originalBinary.suppPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSupp error:nil];
    
    [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];
    
    if (dumpResult == 0)
        return YES;
    
    return NO;
}

@end

/*
 // debug
 
 static void image_added(const struct mach_header *mh, intptr_t slide) {
 Dl_info image_info;
 int result = dladdr(mh, &image_info);
 
 gbprintln(@"loaded lib %@",[NSString stringWithUTF8String:image_info.dli_fname]);
 
 //dumptofile(image_info.dli_fname, mh);
 }
 
 static void image_removed(const struct mach_header *mh, intptr_t slide) {
 Dl_info image_info;
 int result = dladdr(mh, &image_info);
 
 gbprintln(@"unloaded lib %@",[NSString stringWithUTF8String:image_info.dli_fname]);
 
 //dumptofile(image_info.dli_fname, mh);
 }
 
 
 __attribute__((constructor))
 static void dumpexecutable() {
 _dyld_register_func_for_add_image(&image_added);
 _dyld_register_func_for_remove_image(&image_removed);

 }*/
