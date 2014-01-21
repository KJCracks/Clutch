//
//  YOPAPackage.m
//  yopa
//

#import "YOPAPackage.h"
#import "out.h"

static NSString * genRandStringLength(int len) {
    NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    
    for (int i=0; i<len; i++) {
        [randomString appendFormat: @"%c", [letters characterAtIndex: arc4random()%[letters length]]];
    }
    
    return randomString;
}


@implementation YOPAPackage

- (id)initWithPackagePath:(NSString*) packagePath {
    if (self = [super init]) {
        _packagePath = packagePath;
        _segments = [[NSArray alloc] init];
        _package = fopen([packagePath UTF8String], "w+");
        
    }
    return self;
}

//installation stuff

-(struct yopa_segment) findCompatibleSegmentforVersion:(NSInteger) version {
    //version should be 0 if there's nothing
    uint32_t magic, offset;
    struct yopa_segment segment;
    for(int i = 0; i < sizeof(_header.segment_offsets) / sizeof(uint32_t); i++)
    {
        offset = _header.segment_offsets[i];
        fseek(_package, CFSwapInt32(offset), SEEK_SET);
        fread(&magic, sizeof(uint32_t), 1, _package);
        if (magic != YOPA_SEGMENT_MAGIC) {
            NSLog(@"Rogue segment detected at %u", CFSwapInt32(offset));
            continue;
        }
        fread(&segment, sizeof(struct yopa_segment), 1, _package);
        if (version == segment.required_version) {
            NSLog(@"Found compatible segment at %u", CFSwapInt32(offset));
            return segment;
        }
    }
    NSLog(@"Error couldn't find any segment");
    return segment;
}



-(NSString*)lipoPackageFromSegment:(struct yopa_segment)segment {
    fseek(_package, segment.offset, SEEK_SET);
    NSString *lipoPath = [_tmpDir stringByAppendingPathComponent:@"package-lipo"]; // assign a new lipo path
    FILE *lipoOut = fopen([lipoPath UTF8String], "w+"); // prepare the file stream
    void *tmp_b = malloc(0x1000); // allocate a temporary buffer
    
    NSUInteger remain = CFSwapInt32(segment.size);
    while (remain > 0) {
        if (remain > 0x1000) {
            // move over 0x1000
            fread(tmp_b, 0x1000, 1, _package);
            fwrite(tmp_b, 0x1000, 1, lipoOut);
            remain -= 0x1000;
        } else {
            // move over remaining and break
            fread(tmp_b, remain, 1, _package);
            fwrite(tmp_b, remain, 1, lipoOut);
            break;
        }
    }
    fclose(lipoOut);
    return lipoPath;
}


-(NSString*) processPackage {
    switch (_header.segment_offsets[0]){
        case SEVENZIP_COMPRESSION: {
            NSLog(@"7zip compression, extracting");
            _tmpDir = [NSString stringWithFormat:@"/tmp/yopa-%@", genRandStringLength(8)];
            NSLog(@"tmp dir %@", _tmpDir);
            if (![[NSFileManager defaultManager] removeItemAtPath:_tmpDir error:nil]) {
                NSLog(@"Could not remove temporary directory? huh");
            }
            
            [[NSFileManager defaultManager] createDirectoryAtPath:_tmpDir withIntermediateDirectories:YES attributes:nil error:nil];
            
            //BOOL result = [LZMAExtractor extractArchiveEntry:_packagePath archiveEntry:@".ipa" outPath:[_tmpDir stringByAppendingPathComponent:@".ipa"]];
            
            NSArray *result;
            //= [LZMAExtractor extract7zArchive:_packagePath dirName:_tmpDir preserveDir:NO];
            
            NSString *item = nil;
            for (NSString *path in result) {
                if ([[[path pathExtension] lowercaseString] isEqualToString:@"ipa"]) {
                    NSLog(@"found IPA in extracted 7z");
                    item = path;
                    break;
                }
            }
            
            return item;
            break;
        }
    }
    return nil;
}

-(NSString*)getTempDir {
    return _tmpDir;
}

-(void)copyFromSegment:(YOPASegment*) segment {
    void *tmp_b = malloc(0x1000); // allocate a temporary buffer
    fseek(segment->_file, 0, SEEK_SET);
    fseek(_package, 0, SEEK_END);
    NSUInteger remain = segment->_size;
    while (remain > 0) {
        if (remain > 0x1000) {
            // move over 0x1000
            fread(tmp_b, 0x1000, 1, segment->_file);
            fwrite(tmp_b, 0x1000, 1, _package);
            remain -= 0x1000;
        } else {
            // move over remaining and break
            fread(tmp_b, remain, 1, segment->_file);
            fwrite(tmp_b, remain, 1, _package);
            break;
        }
    }
}

-(void)writeSegments {
    uint32_t segment_magic = YOPA_SEGMENT_MAGIC;
    for (YOPASegment* segment in _segments) {
        //get current length/offset of package
        segment->_offset = (uint32_t) ftell(_package);
       
        //copy into final package
        [self copyFromSegment:segment];
        fseek(_package, 0, SEEK_END);
        
        //write segment header
        struct yopa_segment segment_header = [segment getSegmentHeader];
        fwrite(&segment_header, sizeof(struct yopa_segment), 1, _package);
        
        //write segment magic
        fwrite(&segment_magic, sizeof(uint32_t), 1, _package);
        
    }
}

- (void)writeHeader
{
    int i = 0;
    for (YOPASegment* segment in _segments) {
        _header.segment_offsets[i] = segment->_offset + segment->_size;
        i++;
    }
    
    fseek(_package, 0, SEEK_END);
    
    DEBUG(@"seek end ok");
    
    fwrite(&_header, sizeof(struct yopa_header), 1, _package); //write header info
    
    DEBUG(@"write header ok");
    
    uint32_t yopa_magic = YOPA_FAT_PACKAGE;
    
    fwrite(&yopa_magic, sizeof(yopa_magic), 1, _package); //write magic
    
    DEBUG(@"write magic ok");
    
    fclose(_package);
}
@end