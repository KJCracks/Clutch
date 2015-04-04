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
#import "NSTask.h"

#import "ClutchBundle.h"

@implementation FrameworkDumper

- (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM;
}

- (BOOL)dumpBinary
{
    
    DumperLog(@"fuck you");
    
    ClutchBundle *_framework = [_originalBinary valueForKey:@"_bundle"];

    NSMutableData *data = [NSMutableData dataWithContentsOfFile:_framework.executable.binaryPath];
    
    insertRPATHIntoBinary(_framework.bundlePath.stringByDeletingLastPathComponent, data, _thinHeader);
    
    [data writeToFile:_framework.executable.binaryPath atomically:YES];
    
    NSError *loadError;
    
    [_framework loadAndReturnError:&loadError];
    
    DumperLog(@"error %@",loadError);
    
    return NO;
    
    _originalBinary = _framework.parentBundle.executable;

    NSString *libClutchPath = @"/libclutch.dylib";//[_originalBinary.workingPath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"libClutch.dylib"];
    
    if (_originalBinary.hasRestrictedSegment) {
        
        // This' actually bullshit, never going to happen. But who knows, it's fucking apple after all =\
        
        // remove libClutch
        [[NSFileManager defaultManager]removeItemAtPath:libClutchPath error:nil];
        
        DumperLog(@"Cannot dump frameworks. The binary has __RESTRICT segment.");
        
        return NO;
    }
    
    NSString *binaryDumpPath = [_originalBinary.workingPath stringByAppendingPathComponent:_originalBinary.binaryPath.lastPathComponent];
    
    NSString* swappedBinaryPath = _originalBinary.binaryPath, *newSinf = _originalBinary.sinfPath, *newSupp = _originalBinary.suppPath; // default values if we dont need to swap archs
    
    //check if cpusubtype matches
    if ((_thinHeader.header.cpusubtype != [Device cpu_subtype]) && (_originalBinary.hasMultipleARMSlices || (_originalBinary.hasARM64Slice && ([Device cpu_type]==CPU_TYPE_ARM64)))) {
        
        NSString* suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:_thinHeader]];
        
        swappedBinaryPath = [_originalBinary.binaryPath stringByAppendingString:suffix];
        newSinf = [_originalBinary.sinfPath.stringByDeletingPathExtension stringByAppendingString:[suffix stringByAppendingPathExtension:_originalBinary.sinfPath.pathExtension]];
        newSupp = [_originalBinary.suppPath.stringByDeletingPathExtension stringByAppendingString:[suffix stringByAppendingPathExtension:_originalBinary.suppPath.pathExtension]];
        
        [self swapArch];
        
    }
    
    [self.originalFileHandle closeFile];
    
    DumperLog(@"Loading %@",_originalBinary);
    
    NSTask *dumpTask = [NSTask new];
    
    dumpTask.launchPath = _originalBinary.binaryPath;
    
    dumpTask.environment = @{@"DYLD_INSERT_LIBRARIES":libClutchPath};
    
    dumpTask.arguments = @[binaryDumpPath,@"test1",@"test2",@"test3"];
    
    NSPipe *pipe=[NSPipe pipe];
    [dumpTask setStandardOutput:pipe];
    [dumpTask setStandardError:pipe];
    NSFileHandle *handle=[pipe fileHandleForReading];
    
    [dumpTask launch];
    
    while (dumpTask.isRunning == YES) {

    }
    
    NSData * dataRead = [handle readDataToEndOfFile];
    NSString * stringRead = [[NSString alloc] initWithData:dataRead encoding:NSUTF8StringEncoding];
    
    DumperLog(@"Dump task did finish %@",stringRead);
    
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
