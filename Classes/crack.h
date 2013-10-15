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
int overdrive_enabled, new_zip;
char buffer[4096];
char old_buffer[4096];
FILE *oldbinary;
struct fat_header* fh;
uint32_t offset;
NSString* sinf_file;
NSString* supp_file;

//if the event of lipo
uint32_t lipo_offset;
uint32_t start;
NSMutableArray* stripHeaders;

int compression_level;

#define NOZIP 1

#define FAT_CIGAM 0xbebafeca
#define MH_MAGIC 0xfeedface

#define CLUTCH_VERSION "Clutch-1.3.1"
#define CLUTCH_BUILD 13104
#define CLUTCH_DEV 0

#define ARMV6 6
#define ARMV7 9
#define ARMV7S 11
#define ARMV8 0

#define CPUTYPE_32 0xc000000
#define CPUTYPE_64 0xc000001


#define ARMV7_SUBTYPE 0x9000000
#define ARMV6_SUBTYPE 0x6000000
#define ARMV7S_SUBTYPE 0xb000000 //ya boooooooo
#define ARMV8_SUBTYPE 0x0000000

//#define DEBUGMODE 1

#ifdef DEBUGMODE
#   define NSLog(...) NSLog(__VA_ARGS__)
#else
#   define NSLog(...)
#endif

NSString * crack_application(NSString *application_basedir, NSString *basename, NSString* version);
NSString * init_crack_binary(NSString *application_basedir, NSString *bdir, NSString *workingDir, NSDictionary *infoplist);
NSString* swap_arch(NSString *binaryPath, NSString* baseDirectory, NSString* baseName, uint32_t swaparch);
NSString * crack_binary(NSString *binaryPath, NSString *finalPath, NSString **error);
NSString * genRandStringLength(int len);
int get_local_arch();
uint32_t get_local_cputype();

int local_arch;
uint32_t local_cputype;

/*struct fat_arch {
	uint32_t cputype;
	uint32_t cpusubtype;
	uint32_t offset;
	uint32_t size;
	uint32_t align;
};*/