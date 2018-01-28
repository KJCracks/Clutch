//
//  SCInfoBuilder.m
//  Clutch
//
//  Created by Anton Titkov on 03.04.15.
//
//

#import "SCInfoBuilder.h"
#import "NSData+Reading.h"
#import "scinfo.h"

@implementation SCInfoBuilder

+ (nullable NSData *)sinfForBundle:(ClutchBundle *)bundle {
    CLUTCH_UNUSED(bundle);
    return nil;
}

+ (NSDictionary *)parseBlob:(NSData *)blobData {

    NSMutableDictionary *_blob = [NSMutableDictionary new];

    NSDictionary *kvalues = @{
        @"frma" : @"string",
        @"schm" : @"data",
        @"user" : @"number",
        @"key " : @"data",
        @"iviv" : @"data",
        @"veID" : @"number",
        @"plat" : @"number",
        @"aver" : @"number",
        @"tran" : @"number",
        @"song" : @"number",
        @"tool" : @"number",
        @"medi" : @"number",
        @"mode" : @"number",
        @"name" : @"string",
        @"priv" : @"data",
        @"sign" : @"data"
    };

    blobData.currentOffset = 0;

    while (1) {

        if (blobData.currentOffset >= blobData.length) {
            break;
        }

        uint32_t _realSize = CFSwapInt32(blobData.nextInt);
        uint32_t _blobSize = _realSize - sizeof(struct sinf_kval);
        uint32_t _blobName = blobData.nextInt;

        NSString *name = @((const char *)&_blobName);

        if (name.length > 4) {
            name = [name substringWithRange:NSMakeRange(0, 4)];
        }

        if ([kvalues.allKeys containsObject:name] && name.length) {

            NSData *valData = [blobData subdataWithRange:NSMakeRange(blobData.currentOffset, _blobSize)];

            if ([kvalues[name] isEqualToString:@"string"]) {
                NSString *val = [[NSString alloc] initWithData:valData encoding:NSASCIIStringEncoding];
                _blob[name] = val;
            } else if ([kvalues[name] isEqualToString:@"data"]) {
                _blob[name] = valData;
            } else if ([kvalues[name] isEqualToString:@"number"]) {
                uint32_t integer;
                [valData getBytes:&integer length:sizeof(integer)];
                _blob[name] = @(CFSwapInt32(integer));
            }

        } else if (name.length && [name isEqualToString:@"schi"]) {
            _blob[name] = [self parseBlob:[blobData subdataWithRange:NSMakeRange(blobData.currentOffset, _blobSize)]];
        } else if (name.length && [name isEqualToString:@"righ"]) {

            NSMutableDictionary *_righ = [NSMutableDictionary new];

            int count = _blobSize / sizeof(struct sinf_kval);

            for (int i = 0; i < count; i++) {

                uint32_t kName = blobData.nextInt;
                uint32_t kValue = blobData.nextInt;

                NSString *name_ = @((const char *)&kName);

                if (name_.length > 4) {
                    name_ = [name_ substringWithRange:NSMakeRange(0, 4)];
                }

                if ([kvalues[name_] isEqualToString:@"number"] && name_.length) {

                    _righ[name_] = @(CFSwapInt32(kValue));
                }
            }

            _blob[name] = _righ.copy;
            continue;
        }

        blobData.currentOffset += _blobSize;
    }

    return _blob.copy;
}

+ (NSDictionary *)parseOriginaleSinfForBundle:(ClutchBundle *)bundle {

    NSMutableDictionary *_sinfDict = [NSMutableDictionary new];

    Binary *executable = bundle.executable;

    NSData *sinfData = [NSData dataWithContentsOfFile:executable.sinfPath];

    uint32_t realSize = CFSwapInt32([sinfData intAtOffset:0]);

    uint32_t blobSize = realSize - sizeof(struct sinf_kval);

    struct sinf_atom sinf;

    [sinfData getBytes:&sinf length:sizeof(sinf)];

    _sinfDict[@"size"] = @(realSize);
    _sinfDict[@"name"] = @((const char *)&sinf.name);
    _sinfDict[@"blob"] = [self parseBlob:[sinfData subdataWithRange:NSMakeRange(sizeof(struct sinf_kval), blobSize)]];

    return _sinfDict.copy;
}

@end
