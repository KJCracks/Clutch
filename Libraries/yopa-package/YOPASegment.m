//
//  YOPASegment.m
//  yopainstalld
//


#import "YOPASegment.h"
#import "YOPAPackage.h"

@implementation YOPASegment

- (id)initWithNormalPackage:(NSString*)packagePath withCompressionType:(int)compressionType withBundleName:(NSString*)bundle
{
    if (self = [super init]) {
        _file = fopen(packagePath.UTF8String, "r");
        fseek(_file, 0, SEEK_END);
        _size = (uint32_t) ftell(_file);
        _packagePath = packagePath;
        _compression_type = compressionType;
        _app_bundle = bundle;
    }
    return self;
}

- (struct yopa_segment)getSegmentHeader {
    struct yopa_segment header;
    header.compression_type = _compression_type;
    //header.size = _size + sizeof(struct yopa_segment) + sizeof(uint32_t); //add the segment size and magic size
    //should segment size and magic size be handled by downloader?
    header.size = _size;
    header.required_version = 0;
    if (strlen(_app_bundle.UTF8String) > 100) {
        NSLog(@"error: app bundle too long");
    }
    strncpy(header.app_bundle, _app_bundle.UTF8String, 100);
    DEBUG(@"app bundle %@", _app_bundle);
    return header;
}

-(void) dealloc {
    fclose(_file);
    [super dealloc];
}


@end
