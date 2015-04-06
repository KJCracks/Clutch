//
//  FrameworkDumper.m
//  Clutch
//
//  Created by Anton Titkov on 02.04.15.
//
//

#import "FrameworkDumper.h"
#import "Device.h"
#import <dlfcn.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <mach/mach_traps.h>
#import <mach/mach_init.h>
#import <mach-o/dyld_images.h>

@implementation FrameworkDumper

- (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM;
}

- (BOOL)dumpBinary
{
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
    
    [newFileHandle seekToFileOffset:_thinHeader.offset];
    
    void * handle = dlopen(swappedBinaryPath.UTF8String, RTLD_LOCAL);
    
    uint32_t imageCount = _dyld_image_count();
    uint32_t dyldIndex = -1;
    for (uint32_t idx = 0; idx < imageCount; idx++) {
        NSString *dyldPath = [NSString stringWithUTF8String:_dyld_get_image_name(idx)];
        
        
        if ([swappedBinaryPath.lastPathComponent isEqualToString:dyldPath.lastPathComponent]) {
            dyldIndex = idx;
            break;
        }
    }
    
    if (dyldIndex == -1) {
        DumperLog(@"dlopen error: %s",dlerror());
        dlclose(handle);
        return NO;
    }
    
    intptr_t dyldPointer = _dyld_get_image_vmaddr_slide(dyldIndex);
    
    BOOL dumpResult = [self _dumpToFileHandle:newFileHandle withEncryptionInfoCommand:(crypt.cryptsize + crypt.cryptoff) pages:pages fromPort:mach_task_self() pid:[NSProcessInfo processInfo].processIdentifier aslrSlide:dyldPointer];
    
    if (dlclose(handle)) {
        DumperLog(@"dlclose error: %s",dlerror());
    }
    
    if (![swappedBinaryPath isEqualToString:_originalBinary.binaryPath])
        [[NSFileManager defaultManager]removeItemAtPath:swappedBinaryPath error:nil];
    if (![newSinf isEqualToString:_originalBinary.sinfPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSinf error:nil];
    if (![newSupp isEqualToString:_originalBinary.suppPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSupp error:nil];
    
    return dumpResult;
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
