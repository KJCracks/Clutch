#import "Configuration.h"
#import "dump.h"
#import "scinfo.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import <sys/stat.h>
#import <utime.h>
#import "out.h"
#include <mach-o/fat.h>
#include <mach-o/loader.h>

//sharing is caring
int overdrive_enabled;
char buffer[4096];
char old_buffer[4096];
FILE *oldbinary;
struct fat_header* fh;
BOOL stripHeader = FALSE;

#define FAT_CIGAM 0xbebafeca
#define MH_MAGIC 0xfeedface

#define CLUTCH_VERSION "Clutch 1.2.4"

#define ARMV6 6
#define ARMV7 9
#define ARMV7S 11

#define ARMV7_SUBTYPE 0x9000000
#define ARMV6_SUBTYPE 0x6000000
#define ARMV7S_SUBTYPE 0xb000000 //ya boooooooo




NSString * crack_application(NSString *application_basedir, NSString *basename);
NSString * init_crack_binary(NSString *application_basedir, NSString *bdir, NSString *workingDir, NSDictionary *infoplist);
FILE* swap_arch(NSString *binaryPath, NSString* baseDirectory, NSString* baseName, uint32_t swaparch);
NSString * crack_binary(NSString *binaryPath, NSString *finalPath, NSString **error);
NSString * genRandStringLength(int len);
int get_local_arch();

/*struct fat_arch {
	uint32_t cputype;
	uint32_t cpusubtype;
	uint32_t offset;
	uint32_t size;
	uint32_t align;
};*/