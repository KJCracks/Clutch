

#define YOPA_MAGIC 0xf00dface

#define ZIP_COMPRESSION 0
#define SEVENZIP_COMPRESSION 7

struct YOPA_Header {
    int compression_format;
  	uint32_t supported_archs[10];
	fpos_t patch_offsets[50];
	int package_version;
	char package_signature;
  	char cracker_name[100];
	char cracker_message[4096];
	
};

@interface YOPAPackage : NSObject
{
    NSString* _ipaPath;
    NSString* _packagePath;
    FILE* _package;
    struct YOPA_Header _header;
}

- (id)initWithIPAPath:(NSString*) ipaPath;
- (void)compressToPackage:(NSString*)packagePath withCompressionType:(int)compressionType;
- (void)addHeaders;

@end