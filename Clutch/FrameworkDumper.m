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
#import "ClutchPrint.h"

@implementation FrameworkDumper

- (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM;
}

- (BOOL)dumpBinary
{

    ClutchBundle *bundle = [_originalBinary valueForKey:@"_bundle"];

    NSString *binaryDumpPath = [_originalBinary.workingPath stringByAppendingPathComponent:_originalBinary.binaryPath.lastPathComponent];


    NSString* swappedBinaryPath = _originalBinary.binaryPath, *newSinf = _originalBinary.sinfPath, *newSupp = _originalBinary.suppPath, *newSupf = _originalBinary.supfPath; // default values if we dont need to swap archs

    //check if cpusubtype matches
    if ((_thinHeader.header.cpusubtype != [Device cpu_subtype]) && (_originalBinary.hasMultipleARMSlices || (_originalBinary.hasARM64Slice && ([Device cpu_type]==CPU_TYPE_ARM64)))) {

        NSString* suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:_thinHeader]];

        swappedBinaryPath = [_originalBinary.binaryPath stringByAppendingString:suffix];
        newSinf = [_originalBinary.sinfPath.stringByDeletingPathExtension stringByAppendingString:[suffix stringByAppendingPathExtension:_originalBinary.sinfPath.pathExtension]];
        newSupp = [_originalBinary.suppPath.stringByDeletingPathExtension stringByAppendingString:[suffix stringByAppendingPathExtension:_originalBinary.suppPath.pathExtension]];
        newSupf = [_originalBinary.supfPath.stringByDeletingPathExtension stringByAppendingString:[suffix stringByAppendingPathExtension:_originalBinary.supfPath.pathExtension]];


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

    [[ClutchPrint sharedInstance] printDeveloper: @"32bit dumping: arch %@ offset %u", [Dumper readableArchFromHeader:_thinHeader], _thinHeader.offset];
    uint32_t cryptlc_offset;

    for (int i = 0; i < _thinHeader.header.ncmds; i++) {

        uint32_t cmd = [newFileHandle intAtOffset:newFileHandle.offsetInFile];
        uint32_t size = [newFileHandle intAtOffset:newFileHandle.offsetInFile+sizeof(uint32_t)];

        switch (cmd) {
            case LC_CODE_SIGNATURE: {
                [newFileHandle getBytes:&ldid inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct linkedit_data_command))];
                foundSignature = YES;

                [[ClutchPrint sharedInstance] printDeveloper: @"FOUND CODE SIGNATURE: dataoff %u | datasize %u",ldid.dataoff,ldid.datasize];

                break;
            }
            case LC_ENCRYPTION_INFO: {
                cryptlc_offset = newFileHandle.offsetInFile;
                [newFileHandle getBytes:&crypt inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct encryption_info_command))];
                foundCrypt = YES;

                [[ClutchPrint sharedInstance] printDeveloper: @"FOUND ENCRYPTION INFO: cryptoff %u | cryptsize %u | cryptid %u",crypt.cryptoff,crypt.cryptsize,crypt.cryptid];

                break;
            }
            case LC_SEGMENT:
            {
                [newFileHandle getBytes:&__text inRange:NSMakeRange(newFileHandle.offsetInFile,sizeof(struct segment_command))];

                if (strncmp(__text.segname, "__TEXT", 6) == 0) {
                    foundStartText = YES;
                    [[ClutchPrint sharedInstance] printDeveloper: @"FOUND %s SEGMENT",__text.segname];
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
        [[ClutchPrint sharedInstance] printDeveloper: @"dumping binary: some load commands were not found %@ %@ %@",foundCrypt?@"YES":@"NO",foundSignature?@"YES":@"NO",foundStartText?@"YES":@"NO"];
        return NO;
    }

    [[ClutchPrint sharedInstance] printDeveloper: @"starting to ldid"];

    NSUInteger begin;

    //seek to ldid offset

    codesignblob = malloc(ldid.datasize);

    [newFileHandle seekToFileOffset:_thinHeader.offset + ldid.dataoff];
    [newFileHandle getBytes:codesignblob inRange:NSMakeRange(newFileHandle.offsetInFile, ldid.datasize)];

    [[ClutchPrint sharedInstance] printDeveloper: @"hello it's me"];

    uint32_t countBlobs = CFSwapInt32(codesignblob->count); // how many indexes?



    for (uint32_t index = 0; index < countBlobs; index++) { // is this the code directory?
        if (CFSwapInt32(codesignblob->index[index].type) == CSSLOT_CODEDIRECTORY) {
            // we'll find the hash metadata in here
            [[ClutchPrint sharedInstance] printDeveloper: @"%u %u %u", _thinHeader.offset, ldid.dataoff, codesignblob->index[index].offset];
            begin = _thinHeader.offset + ldid.dataoff + CFSwapInt32(codesignblob->index[index].offset); // store the top of the codesign directory blob
            [newFileHandle getBytes:&directory inRange:NSMakeRange(begin, sizeof(struct code_directory))]; //read the blob from its beginning
            [[ClutchPrint sharedInstance] printDeveloper: @"Found CSSLOT_CODEDIRECTORY"];
            break; //break (we don't need anything from this the superblob anymore)
        }
    }
    free(codesignblob);

    uint32_t pages = CFSwapInt32(directory.nCodeSlots); // get the amount of codeslots

    if (pages == 0) {
        [[ClutchPrint sharedInstance] printColor:ClutchPrinterColorPurple format:@"pages == 0"];
        return NO;
    }

    [newFileHandle closeFile];


    [[ClutchPrint sharedInstance] printDeveloper: @"hello from the other side"];

    extern char **environ;
    posix_spawnattr_t attr;

    pid_t pid;



    NSUUID* workingUUID = [NSUUID new];
    NSString* workingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"clutch" stringByAppendingPathComponent:workingUUID.UUIDString]];

    while ([[NSFileManager defaultManager] fileExistsAtPath:workingPath]) {
        workingUUID = [NSUUID new];
        workingPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"clutch" stringByAppendingPathComponent:workingUUID.UUIDString]];
    }

    [[NSFileManager defaultManager] createDirectoryAtPath:workingPath withIntermediateDirectories:YES attributes:nil error:nil];



    if (![[NSFileManager defaultManager] copyItemAtPath:[NSProcessInfo processInfo].arguments[0] toPath:[workingPath stringByAppendingPathComponent:@"clutch"] error:nil]) {
        [[ClutchPrint sharedInstance] printError:@"Failed to copy clutch to %@", workingPath];
        return NO;
    }

    if (_originalBinary.frameworksPath == nil) {
        [[ClutchPrint sharedInstance] printError:@"Could not find Frameworks path to create symbolic link to"];
        return NO;
    }

    [[NSFileManager defaultManager] createSymbolicLinkAtPath:[workingPath stringByAppendingPathComponent:@"Frameworks"] withDestinationPath:_originalBinary.frameworksPath error:nil];

    const char *argv[] = {[[workingPath stringByAppendingPathComponent:@"clutch"] UTF8String],
        "-f",
        swappedBinaryPath.UTF8String,
        binaryDumpPath.UTF8String,
        [NSString stringWithFormat:@"%u",pages].UTF8String,
        [NSString stringWithFormat:@"%u",_thinHeader.header.ncmds].UTF8String,
        [NSString stringWithFormat:@"%u",_thinHeader.offset].UTF8String,
        bundle.parentBundle.bundleIdentifier.UTF8String,
        [NSString stringWithFormat:@"%u",CFSwapInt32(directory.hashOffset)].UTF8String,
        [NSString stringWithFormat:@"%u",(unsigned int)begin].UTF8String,
        [NSString stringWithFormat:@"%u", crypt.cryptoff].UTF8String,
        [NSString stringWithFormat:@"%u", crypt.cryptsize].UTF8String,
        [NSString stringWithFormat:@"%u", cryptlc_offset].UTF8String,
        NULL};

    [[ClutchPrint sharedInstance] printDeveloper: @"i must have called a thousand times!"];

    [[ClutchPrint sharedInstance] printDeveloper: @"hello potato posix_spawn %@", [[NSString alloc] initWithUTF8String:argv[0]]];


    posix_spawnattr_init (&attr);

    size_t ocount = 0;

    cpu_type_t cpu_type = CPU_TYPE_ARM;


    posix_spawnattr_setbinpref_np (&attr, 1, &cpu_type, &ocount);


    short flags = POSIX_SPAWN_START_SUSPENDED;
    // Set the flags we just made into our posix spawn attributes
    exit_with_errno (posix_spawnattr_setflags (&attr, flags), "::posix_spawnattr_setflags (&attr, flags) error: ");

    int dumpResult = posix_spawnp(&pid, argv[0], NULL, &attr, (char* const*)argv, environ);
    __block NSUInteger finalDumpResult = 9999; //it shouldn't be 9999

    if (dumpResult == 0) {
        [[ClutchPrint sharedInstance] printDeveloper: @"Child pid: %i", pid];

        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

        dispatch_sync(queue, ^{
            kill(pid, SIGCONT);
			int dumpResult = 0;
            if (waitpid(pid, &dumpResult, 0) != -1) {
                [[ClutchPrint sharedInstance] printDeveloper: @"Child exited with status %u", dumpResult];
                finalDumpResult = dumpResult;
            } else {
                perror("waitpid");
            }
        });

    } else {
        [[ClutchPrint sharedInstance] printDeveloper: @"posix_spawn: %s", strerror(dumpResult)];
    }


    if (![swappedBinaryPath isEqualToString:_originalBinary.binaryPath])
        [[NSFileManager defaultManager]removeItemAtPath:swappedBinaryPath error:nil];
    if (![newSinf isEqualToString:_originalBinary.sinfPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSinf error:nil];
    if (![newSupp isEqualToString:_originalBinary.suppPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSupp error:nil];

    [[NSFileManager defaultManager] removeItemAtPath:workingPath error:nil];



    if (finalDumpResult == 0)
        return YES;

    return NO;
}

@end
