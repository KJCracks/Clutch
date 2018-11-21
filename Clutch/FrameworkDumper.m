//
//  FrameworkDumper.m
//  Clutch
//
//  Created by Anton Titkov on 02.04.15.
//
//

#import "FrameworkDumper.h"
#import "ClutchPrint.h"
#import "Device.h"
#import <spawn.h>

@implementation FrameworkDumper

- (cpu_type_t)supportedCPUType {
    return CPU_TYPE_ARM;
}

- (BOOL)dumpBinary {

    ClutchBundle *bundle = [self.originalBinary valueForKey:@"_bundle"];

    NSString *binaryDumpPath = [self.originalBinary.workingPath
        stringByAppendingPathComponent:self.originalBinary.binaryPath.lastPathComponent];

    NSString *swappedBinaryPath = self.originalBinary.binaryPath, *newSinf = self.originalBinary.sinfPath,
             *newSupp = self.originalBinary.suppPath; // default values if we dont need to swap archs

    // check if cpusubtype matches
    if ((self.thinHeader.header.cpusubtype != [Device cpu_subtype]) &&
        (self.originalBinary.hasMultipleARMSlices ||
         (self.originalBinary.hasARM64Slice && ([Device cpu_type] == CPU_TYPE_ARM64)))) {

        NSString *suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:self.thinHeader]];

        swappedBinaryPath = [self.originalBinary.binaryPath stringByAppendingString:suffix];
        newSinf = [self.originalBinary.sinfPath.stringByDeletingPathExtension
            stringByAppendingString:[suffix stringByAppendingPathExtension:self.originalBinary.sinfPath.pathExtension]];
        newSupp = [self.originalBinary.suppPath.stringByDeletingPathExtension
            stringByAppendingString:[suffix stringByAppendingPathExtension:self.originalBinary.suppPath.pathExtension]];

        [self swapArch];
    }

    NSFileHandle *newFileHandle =
        [[NSFileHandle alloc] initWithFileDescriptor:fileno(fopen(binaryDumpPath.UTF8String, "r+"))];

    [newFileHandle seekToFileOffset:self.thinHeader.offset + self.thinHeader.size];

    struct linkedit_data_command ldid;    // LC_CODE_SIGNATURE load header (for resign)
    struct encryption_info_command crypt; // LC_ENCRYPTION_INFO load header (for crypt*)
    struct segment_command __text;        // __TEXT segment

    struct super_blob *codesignblob; // codesign blob pointer
    struct code_directory directory; // codesign directory index

    BOOL foundCrypt = NO, foundSignature = NO, foundStartText = NO;
    directory.nCodeSlots = directory.hashOffset = 0;

    KJDebug(
        @"32bit dumping: arch %@ offset %u", [Dumper readableArchFromHeader:self.thinHeader], self.thinHeader.offset);
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
            case LC_ENCRYPTION_INFO: {
                cryptlc_offset = (uint32_t)(newFileHandle.offsetInFile);
                [newFileHandle getBytes:&crypt
                                inRange:NSMakeRange((NSUInteger)(newFileHandle.offsetInFile),
                                                    sizeof(struct encryption_info_command))];
                foundCrypt = YES;

                KJDebug(@"FOUND ENCRYPTION INFO: cryptoff %u | cryptsize %u | cryptid %u",
                        crypt.cryptoff,
                        crypt.cryptsize,
                        crypt.cryptid);

                break;
            }
            case LC_SEGMENT: {
                [newFileHandle
                    getBytes:&__text
                     inRange:NSMakeRange((NSUInteger)(newFileHandle.offsetInFile), sizeof(struct segment_command))];

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

    KJDebug(@"starting to ldid");

    NSUInteger begin = 0;

    // seek to ldid offset

    codesignblob = malloc(ldid.datasize);

    [newFileHandle seekToFileOffset:self.thinHeader.offset + ldid.dataoff];
    [newFileHandle getBytes:codesignblob inRange:NSMakeRange((NSUInteger)(newFileHandle.offsetInFile), ldid.datasize)];

    KJDebug(@"hello it's me");

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
        KJPrint(@"pages == 0");
        return NO;
    }

    [newFileHandle closeFile];

    KJDebug(@"hello from the other side");

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

    KJDebug(@"i must have called a thousand times!");

    KJDebug(@"hello potato posix_spawn %@", @(argv[0]));

    posix_spawnattr_init(&attr);

    size_t ocount = 0;

    cpu_type_t cpu_type = CPU_TYPE_ARM;

    posix_spawnattr_setbinpref_np(&attr, 1, &cpu_type, &ocount);

    short flags = POSIX_SPAWN_START_SUSPENDED;
    // Set the flags we just made into our posix spawn attributes
    exit_with_errno(posix_spawnattr_setflags(&attr, flags), "::posix_spawnattr_setflags (&attr, flags) error: ");

    int dumpResult = posix_spawnp(&pid, argv[0], NULL, &attr, (char *const *)argv, environ);
    __block NSUInteger finalDumpResult = 9999; // it shouldn't be 9999

    if (dumpResult == 0) {
        KJDebug(@"Child pid: %i", pid);

        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

        dispatch_sync(queue, ^{
            kill(pid, SIGCONT);
            int dumpResult_ = 0;
            if (waitpid(pid, &dumpResult_, 0) != -1) {
                KJDebug(@"Child exited with status %u", dumpResult);
                finalDumpResult = WEXITSTATUS(dumpResult_);
            } else {
                perror("waitpid");
            }
        });

    } else {
        KJDebug(@"posix_spawn: %s", strerror(dumpResult));
    }

    if (![swappedBinaryPath isEqualToString:self.originalBinary.binaryPath])
        [[NSFileManager defaultManager] removeItemAtPath:swappedBinaryPath error:nil];
    if (![newSinf isEqualToString:self.originalBinary.sinfPath])
        [[NSFileManager defaultManager] removeItemAtPath:newSinf error:nil];
    if (![newSupp isEqualToString:self.originalBinary.suppPath])
        [[NSFileManager defaultManager] removeItemAtPath:newSupp error:nil];

    [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];

    if (finalDumpResult == 0)
        return YES;

    return NO;
}

@end
