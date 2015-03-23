//
//  Dumper.m
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "Dumper.h"
#import "Device.h"

#import <spawn.h>

#ifndef _POSIX_SPAWN_DISABLE_ASLR
#define _POSIX_SPAWN_DISABLE_ASLR       0x0100
#endif

@implementation Dumper

- (instancetype)initWithHeader:(thin_header)macho originalBinary:(Binary *)binary {

    if (self = [super init]) {
        _thinHeader = macho;
        _originalBinary = binary;
    }
    
    return self;
}

+ (NSString *)readableArchFromHeader:(thin_header)macho
{
    if (macho.header.cputype == CPU_TYPE_ARM64)
        return @"arm64";
    else if (macho.header.cpusubtype == CPU_SUBTYPE_ARM_V6)
        return @"armv6";
    else if (macho.header.cpusubtype == CPU_SUBTYPE_ARM_V7)
        return @"armv7";
    else if (macho.header.cpusubtype == CPU_SUBTYPE_ARM_V7S)
        return @"armv7s";
    
    return @"unknown";
}

static void
exit_with_errno (int err, const char *prefix)
{
    if (err)
    {
        fprintf (stderr,
                 "%s%s",
                 prefix ? prefix : "",
                 strerror(err));
        exit (err);
    }
}

- (pid_t)posix_spawn
{
    pid_t pid = 0;
    
    const char *path = _originalBinary.binaryPath.UTF8String;
    
    posix_spawnattr_t attr;
    
    exit_with_errno (posix_spawnattr_init (&attr), "::posix_spawnattr_init (&attr) error: ");
    
    // Here we are using a darwin specific feature that allows us to exec only
    // since we want this program to turn into the program we want to debug,
    // and also have the new program start suspended (right at __dyld_start)
    // so we can debug it
    short flags = POSIX_SPAWN_START_SUSPENDED | POSIX_SPAWN_SETEXEC;
    
    // Disable ASLR
    flags |= _POSIX_SPAWN_DISABLE_ASLR;
    
    // Set the flags we just made into our posix spawn attributes
    exit_with_errno (posix_spawnattr_setflags (&attr, flags), "::posix_spawnattr_setflags (&attr, flags) error: ");
    
    
    // Another darwin specific thing here where we can select the architecture
    // of the binary we want to re-exec as.
    size_t ocount = 0;
    exit_with_errno (posix_spawnattr_setbinpref_np (&attr, 1, &_thinHeader.header.cputype, &ocount), "posix_spawnattr_setbinpref_np () error: ");
    
    // I wish there was a posix_spawn flag to change the working directory of
    // the inferior process we will spawn, but there currently isn't. If there
    // ever is a better way to do this, we should use it. I would rather not
    // manually fork, chdir in the child process, and then posix_spawn with exec
    // as the whole reason for doing posix_spawn is to not hose anything up
    // after the fork and prior to the exec...
    //if (working_dir)
    //    chdir (working_dir);
    
    exit_with_errno (posix_spawnp (&pid, path, NULL, &attr, NULL, NULL), "posix_spawn() error: ");
    
    posix_spawnattr_destroy (&attr);
    
    return pid;
}

- (cpu_type_t)supportedCPUType
{
#warning not implemented on purpose
    return NULL;
}

- (BOOL)dumpBinaryToURL:(NSURL *)newLocURL
{
#warning not implemented on purpose
    return NO;
}

- (ArchCompatibility)compatibilityMode;
{
    cpu_type_t cputype = self.supportedCPUType;
    cpu_subtype_t cpusubtype = _thinHeader.header.cpusubtype;
    
    if ((cputype != _thinHeader.header.cputype) || (cpusubtype > Device.cpu_subtype) || (_thinHeader.header.cputype > Device.cpu_type)) {
        return ArchCompatibilityNotCompatible;
    }
    
    return ArchCompatibilityCompatible;

}

@end
