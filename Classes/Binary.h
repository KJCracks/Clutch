#import <Foundation/Foundation.h>
#import "out.h"
#import "Preferences.h"

#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <mach-o/arch.h>


@interface Binary : NSObject
{
    @public
    BOOL overdriveEnabled;
    BOOL skip_64;
    BOOL patchPIE;
    BOOL isFramework;
}

- (id)initWithBinary:(NSString *)path;
- (BOOL)crackBinaryToFile:(NSString *)path error:(NSError **)error;
- (BOOL)dumpOrigFile:(FILE *) origin withLocation:(NSString*)originPath toFile:(FILE *) target withArch:(struct fat_arch)arch;
- (BOOL)dump64bitOrigFile:(FILE *) origin withLocation:(NSString*)originPath toFile:(FILE *) target withTop:(uint32_t) top;
- (BOOL)dump32bitOrigFile:(FILE *) origin withLocation:(NSString*)originPath toFile:(FILE *) target withTop:(uint32_t) top;

@end
