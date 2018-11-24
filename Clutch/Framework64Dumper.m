//
//  Framework64Dumper.m
//  Clutch
//
//  Created by Anton Titkov on 02.04.15.
//
//

#import "Framework64Dumper.h"
#import "ClutchPrint.h"
#import "Device.h"
#import <spawn.h>

@implementation Framework64Dumper

- (cpu_type_t)supportedCPUType {
    return CPU_TYPE_ARM64;
}

- (BOOL)dumpBinary {

    ClutchBundle *bundle = [self.originalBinary valueForKey:@"_bundle"];

    NSString *binaryDumpPath = [self.originalBinary.workingPath
        stringByAppendingPathComponent:self.originalBinary.binaryPath.lastPathComponent];

    NSString *swappedBinaryPath = self.originalBinary.binaryPath, *newSinf = self.originalBinary.sinfPath,
             *newSupp = self.originalBinary.suppPath,
             *newSupf = self.originalBinary.supfPath; // default values if we dont need to swap archs

    // check if cpusubtype matches
    if ((self.thinHeader.header.cpusubtype != [Device cpu_subtype]) && self.originalBinary.hasMultipleARM64Slices) {
        NSString *suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:self.thinHeader]];

        swappedBinaryPath = [self.originalBinary.binaryPath stringByAppendingString:suffix];
        newSinf = [self.originalBinary.sinfPath.stringByDeletingPathExtension
            stringByAppendingString:[suffix stringByAppendingPathExtension:self.originalBinary.sinfPath.pathExtension]];
        newSupp = [self.originalBinary.suppPath.stringByDeletingPathExtension
            stringByAppendingString:[suffix stringByAppendingPathExtension:self.originalBinary.suppPath.pathExtension]];
        newSupf = [self.originalBinary.supfPath.stringByDeletingPathExtension
            stringByAppendingString:[suffix stringByAppendingPathExtension:self.originalBinary.supfPath.pathExtension]];

        [self swapArch];
    }

    NSFileHandle *newFileHandle =
        [[NSFileHandle alloc] initWithFileDescriptor:fileno(fopen(binaryDumpPath.UTF8String, "r+"))];

    [newFileHandle seekToFileOffset:self.thinHeader.offset + self.thinHeader.size];

    struct linkedit_data_command ldid;       // LC_CODE_SIGNATURE load header (for resign)
    struct encryption_info_command_64 crypt; // LC_ENCRYPTION_INFO load header (for crypt*)
    struct segment_command_64 __text;        // __TEXT segment

    struct super_blob *codesignblob; // codesign blob pointer
    struct code_directory directory; // codesign directory index

    directory.nCodeSlots = 0;
    directory.hashOffset = 0;
    BOOL foundCrypt = NO, foundSignature = NO, foundStartText = NO;

    KJDebug(
        @"64bit dumping: arch %@ offset %u", [Dumper readableArchFromHeader:self.thinHeader], self.thinHeader.offset);

    uint32_t cryptlc_offset = 0;

    for (unsigned int i = 0; i < self.thinHeader.header.ncmds; i++) {

        uint32_t cmd = [newFileHandle unsignedInt32Atoffset:newFileHandle.offsetInFile];
        uint32_t size = [newFileHandle unsignedInt32Atoffset:newFileHandle.offsetInFile + sizeof(uint32_t)];

        switch (cmd) {
            case LC_CODE_SIGNATURE: {
                [newFileHandle getBytes:&ldid
                                inRange:NSMakeRange((NSUInteger)(newFileHandle.offsetInFile),
                                                    sizeof(struct linkedit_data_command))];
                foundSignature = YES;

                KJDebug(@"FOUND CODE SIGNATURE: dataoff %u | datasize %u", ldid.dataoff, ldid.datasize);

                break;
            }
            case LC_ENCRYPTION_INFO_64: {
                cryptlc_offset = (uint32_t)(newFileHandle.offsetInFile);
                [newFileHandle getBytes:&crypt
                                inRange:NSMakeRange((NSUInteger)(newFileHandle.offsetInFile),
                                                    sizeof(struct encryption_info_command_64))];
                foundCrypt = YES;

                KJDebug(@"FOUND ENCRYPTION INFO: cryptoff %u | cryptsize %u | cryptid %u",
                        crypt.cryptoff,
                        crypt.cryptsize,
                        crypt.cryptid);

                break;
            }
            case LC_SEGMENT_64: {
                [newFileHandle
                    getBytes:&__text
                     inRange:NSMakeRange((NSUInteger)(newFileHandle.offsetInFile), sizeof(struct segment_command_64))];

                if (strncmp(__text.segname, "__TEXT", 6) == 0) {
                    foundStartText = YES;
                    KJDebug(@"FOUND %s SEGMENT", __text.segname);
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
        KJDebug(@"dumping binary: some load commands were not found %@ %@ %@",
                foundCrypt ? @"YES" : @"NO",
                foundSignature ? @"YES" : @"NO",
                foundStartText ? @"YES" : @"NO");
        return NO;
    }

    NSUInteger begin = 0;
    codesignblob = malloc(ldid.datasize);
    // seek to ldid offset

    [newFileHandle seekToFileOffset:self.thinHeader.offset + ldid.dataoff];
    [newFileHandle getBytes:codesignblob inRange:NSMakeRange((NSUInteger)(newFileHandle.offsetInFile), ldid.datasize)];

    uint32_t countBlobs = CFSwapInt32(codesignblob->count); // how many indexes?

    for (uint32_t index = 0; index < countBlobs; index++) { // is this the code directory?
        if (CFSwapInt32(codesignblob->index[index].type) == CSSLOT_CODEDIRECTORY) {
            // we'll find the hash metadata in here
            KJDebug(@"%u %u %u", self.thinHeader.offset, ldid.dataoff, codesignblob->index[index].offset);
            begin = self.thinHeader.offset + ldid.dataoff +
                    CFSwapInt32(codesignblob->index[index].offset); // store the top of the codesign directory blob
            [newFileHandle
                getBytes:&directory
                 inRange:NSMakeRange(begin, sizeof(struct code_directory))]; // read the blob from its beginning
            KJDebug(@"Found CSSLOT_CODEDIRECTORY");
            break; // break (we don't need anything from this the superblob anymore)
        }
    }
    free(codesignblob);

    uint32_t pages = CFSwapInt32(directory.nCodeSlots); // get the amount of codeslots

    if (pages == 0) {
        KJPrintVerbose(@"pages == 0");
        return NO;
    }

    [newFileHandle closeFile];

    extern char **environ;
    posix_spawnattr_t attr;

    pid_t pid;

    NSUUID *workingUUID = [NSUUID new];
    NSString *workingPath = [NSTemporaryDirectory()
        stringByAppendingPathComponent:[@"clutch" stringByAppendingPathComponent:workingUUID.UUIDString]];

    while ([[NSFileManager defaultManager] fileExistsAtPath:workingPath]) {
        workingUUID = [NSUUID new];
        workingPath = [NSTemporaryDirectory()
            stringByAppendingPathComponent:[@"clutch" stringByAppendingPathComponent:workingUUID.UUIDString]];
    }

    [[NSFileManager defaultManager] createDirectoryAtPath:workingPath
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    if (![[NSFileManager defaultManager] copyItemAtPath:[NSProcessInfo processInfo].arguments[0]
                                                 toPath:[workingPath stringByAppendingPathComponent:@"clutch"]
                                                  error:nil]) {
        KJPrint(@"Failed to copy clutch to %@", workingPath);
        return NO;
    }

    if (self.originalBinary.frameworksPath == nil) {
        KJPrint(@"Could not find Frameworks path to create symbolic link to");
        return NO;
    }

    KJDebug(@"cryptlc_offset %u", cryptlc_offset);

    [[NSFileManager defaultManager] createSymbolicLinkAtPath:[workingPath stringByAppendingPathComponent:@"Frameworks"]
                                         withDestinationPath:self.originalBinary.frameworksPath
                                                       error:nil];

    const char *argv[] = {[workingPath stringByAppendingPathComponent:@"clutch"].UTF8String,
                          "-f",
                          swappedBinaryPath.UTF8String,
                          binaryDumpPath.UTF8String,
                          [NSString stringWithFormat:@"%u", pages].UTF8String,
                          [NSString stringWithFormat:@"%u", self.thinHeader.header.ncmds].UTF8String,
                          [NSString stringWithFormat:@"%u", self.thinHeader.offset].UTF8String,
                          bundle.parentBundle.bundleIdentifier.UTF8String,
                          [NSString stringWithFormat:@"%u", CFSwapInt32(directory.hashOffset)].UTF8String,
                          [NSString stringWithFormat:@"%u", (unsigned int)begin].UTF8String,
                          [NSString stringWithFormat:@"%u", crypt.cryptoff].UTF8String,
                          [NSString stringWithFormat:@"%u", crypt.cryptsize].UTF8String,
                          [NSString stringWithFormat:@"%u", cryptlc_offset].UTF8String,
                          NULL};

    NSString *ns_argv = @"";
    for (size_t i = 0; argv[i] != NULL; i++) {
        ns_argv = [ns_argv stringByAppendingFormat:@"%s ", argv[i]];
    }
    KJDebug(@"hello potato posix_spawn %@", ns_argv);

    posix_spawnattr_init(&attr);

    size_t ocount = 0;

    cpu_type_t cpu_type = CPU_TYPE_ARM64; // 64bit Clutch to dump 64bit framework

    posix_spawnattr_setbinpref_np(&attr, 1, &cpu_type, &ocount);

    short flags = POSIX_SPAWN_START_SUSPENDED;
    // Set the flags we just made into our posix spawn attributes
    exit_with_errno(posix_spawnattr_setflags(&attr, flags), "::posix_spawnattr_setflags (&attr, flags) error: ");

    int dumpResult = posix_spawnp(&pid, argv[0], NULL, &attr, (char *const *)argv, environ);
    __block int finalDumpResult = 9999;

    if (dumpResult == 0) {
        KJDebug(@"Child pid: %i", pid);

        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

        dispatch_sync(queue, ^{
            int dumpResult_ = 0;
            kill(pid, SIGCONT);
            if (waitpid(pid, &dumpResult_, 0) != -1) {
                KJPrintVerbose(@"Child exited with status %u", dumpResult_);
                finalDumpResult = WEXITSTATUS(dumpResult_);
            } else {
                KJPrintVerbose(@"waitpid");
            }
        });

    } else {
        KJPrint(@"posix_spawn: %s (Error %u)", strerror(dumpResult), dumpResult);
    }

    if (![swappedBinaryPath isEqualToString:self.originalBinary.binaryPath])
        [[NSFileManager defaultManager] removeItemAtPath:swappedBinaryPath error:nil];
    if (![newSinf isEqualToString:self.originalBinary.sinfPath])
        [[NSFileManager defaultManager] removeItemAtPath:newSinf error:nil];
    if (![newSupp isEqualToString:self.originalBinary.suppPath])
        [[NSFileManager defaultManager] removeItemAtPath:newSupp error:nil];
    if (![newSupf isEqualToString:self.originalBinary.supfPath])
        [[NSFileManager defaultManager] removeItemAtPath:newSupf error:nil];

    [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];

    KJDebug(@"Final dump result %u", finalDumpResult);

    if (finalDumpResult == 0)
        return YES;

    return NO;
}

@end
