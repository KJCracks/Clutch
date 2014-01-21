//
//  YOPAPackage.h
//  yopa
//

#import <Foundation/Foundation.h>
#import "YOPASegment.h"
#pragma pack(1)

#define NOLZMA 1

#define YOPA_HEADER_MAGIC 0xf00dface
#define YOPA_SEGMENT_MAGIC 0xcafef00d //better than mcdonalds

#define ZIP_COMPRESSION 0
#define SEVENZIP_COMPRESSION 7

typedef enum {
    YOPA_SEGMENT,
    YOPA_FAT_PACKAGE,
    UNKNOWN
} PackageType;

struct yopa_segment {
    int16_t compression_type;
    uint32_t offset;
    uint32_t size;
    int16_t required_version; //0 if no required version
    char app_bundle[100];
    char cracker_name[100];
	char cracker_message[4096];    
};

struct yopa_header {
    uint32_t segment_offsets[10];
    char app_bundle[100];
	
};

@interface YOPAPackage : NSObject
{
    NSString* _packagePath;
    FILE* _package;
    struct yopa_header _header;
    NSArray* _segments;
    NSString* _tmpDir;
}

- (id)initWithPackagePath:(NSString*) packagePath;
- (NSString*) processPackage;
- (BOOL) isYOPA;
- (NSString*)getTempDir;

- (void)addSegment:(YOPASegment*)segment;

@end
