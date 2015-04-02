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
    if ((_thinHeader.header.cpusubtype != [Device cpu_subtype]) && (_originalBinary.hasMultipleARMSlices || (_originalBinary.hasARM64Slice && ([Device cpu_type]==CPU_TYPE_ARM64)))) {
        
        NSString* suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:_thinHeader]];
        
        swappedBinaryPath = [_originalBinary.binaryPath stringByAppendingString:suffix];
        newSinf = [_originalBinary.sinfPath stringByAppendingString:suffix];
        newSupp = [_originalBinary.suppPath stringByAppendingString:suffix];
        
        [self swapArch];
        
    }
    
    [self.originalFileHandle closeFile];
    
    gbprintln(@"Loading %@",_originalBinary);
    
    void *fmwkHeader = dlopen(swappedBinaryPath.UTF8String, RTLD_NOW);
    
    if (fmwkHeader == NULL) {
        gbprintln(@"Failed to load framework %@ with error %@",_originalBinary,[NSString stringWithUTF8String:dlerror()]);
        return NO;
    }
    
    dlclose(fmwkHeader);
    
    if (![swappedBinaryPath isEqualToString:_originalBinary.binaryPath])
        [[NSFileManager defaultManager]removeItemAtPath:swappedBinaryPath error:nil];
    if (![newSinf isEqualToString:_originalBinary.sinfPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSinf error:nil];
    if (![newSupp isEqualToString:_originalBinary.suppPath])
        [[NSFileManager defaultManager]removeItemAtPath:newSupp error:nil];
    
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
