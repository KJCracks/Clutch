//
//  YOPASegment.h
//  yopainstalld
//
//  Created by Terence Tan on 20/1/14.
//
//

#import <Foundation/Foundation.h>

@interface YOPASegment : NSObject {
    @public
    FILE* _file;
    NSString* _packagePath;
    int16_t _compression_type;
    uint32_t _offset;
    uint32_t _size;
    int16_t _required_version; //0 if no required version
    NSString* _app_bundle;
    NSString* _cracker_name;
	NSString* _cracker_message;
}

- (struct yopa_segment)getSegmentHeader;

@end
