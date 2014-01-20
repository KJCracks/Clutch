//
//  YOPAPackage.m
//  Clutch


#import "YOPAPackage.h"
#import "out.h"

@implementation YOPAPackage

- (id)initWithIPAPath:(NSString*) ipaPath
{
    if (self = [super init])
    {
        _ipaPath = ipaPath;
    }
    
    return self;
}
- (void)compressToPackage:(NSString*)packagePath withCompressionType:(int)compressionType
{
    _packagePath = packagePath;
    _header.compression_format = compressionType;
    
    if (compressionType == SEVENZIP_COMPRESSION)
    {
        DEBUG(@"7zip compression");
        DEBUG(@"%@", [NSString stringWithFormat:@"7z a \"%@\" \"%@\"", _packagePath, _ipaPath]);
        
        system([[NSString stringWithFormat:@"7z a \"%@\" \"%@\"", _packagePath, _ipaPath] UTF8String]);
    }
    else
    {
        DEBUG(@"unknown compresission");
    }
}

- (void)addHeaders
{
    _package = fopen([_packagePath UTF8String], "a");
    
    DEBUG(@"fopen ok");
    
    fseek(_package, 0, SEEK_END);
    
    DEBUG(@"seek end ok");
    
    fwrite(&_header, sizeof(struct YOPA_Header), 1, _package); //write header info
    
    DEBUG(@"write header ok");
    
    uint32_t yopa_magic = YOPA_MAGIC;
    
    fwrite(&yopa_magic, sizeof(yopa_magic), 1, _package); //write YOPA_MAGIC
    
    DEBUG(@"write magic ok");
    
    fclose(_package);
}

@end
