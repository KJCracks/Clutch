//
//  YOPAPackage.m
//  Clutch


#import "YOPAPackage.h"
#import "out.h"

@implementation YOPAPackage

- (id)initWithIPAPath:(NSString*) ipaPath {
    if (self = [super init]) {
        _ipaPath = ipaPath;
    }
    return self;
}
- (void)compressToPackage:(NSString*)packagePath withCompressionType:(int)compressionType {
    _packagePath = packagePath;
    _header.compression_format = compressionType;
    if (compressionType == SEVENZIP_COMPRESSION) {
        DebugLog(@"7zip compression");
        DebugLog(@"%@", [NSString stringWithFormat:@"7z a \"%@\" \"%@\"", _packagePath, _ipaPath]);
        system([[NSString stringWithFormat:@"7z a \"%@\" \"%@\"", _packagePath, _ipaPath] UTF8String]);
    }
    else {
        DebugLog(@"unknown compresission");
    }
}
- (void)addHeaders {
    _package = fopen([_packagePath UTF8String], "a");
    DebugLog(@"fopen ok");
    fseek(_package, 0, SEEK_END);
    DebugLog(@"seek end ok");
    fwrite(&_header, sizeof(struct YOPA_Header), 1, _package); //write header info
    DebugLog(@"write header ok");
    uint32_t yopa_magic = 0xf00dface;
    fwrite(&yopa_magic, sizeof(yopa_magic), 1, _package); //write YOPA_MAGIC
    DebugLog(@"write magic ok");
    fclose(_package);
}

@end
