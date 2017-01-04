//
//  NSFileHandle+Private.h
//  Clutch
//
//  Created by Anton Titkov on 01.04.15.
//
//

#import <Foundation/Foundation.h>

@interface NSFileHandle (Private)

- (uint32_t)intAtOffset:(unsigned long long)offset;
- (void)replaceBytesInRange:(NSRange)range withBytes:(const void *)bytes;
- (void)getBytes:(void*)result atOffset:(NSUInteger)offset length:(NSUInteger)length;
- (void)getBytes:(void*)result inRange:(NSRange)range;
//- (bool)hk_readValue:(void*)arg1 ofSize:(unsigned long long)arg2;
//- (bool)hk_writeValue:(const void*)arg1 size:(unsigned long long)arg2;

@end
