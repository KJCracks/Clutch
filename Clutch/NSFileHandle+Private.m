//
//  NSFileHandle+Private.m
//  Clutch
//
//  Created by Anton Titkov on 01.04.15.
//
//

#import "NSFileHandle+Private.h"

@implementation NSFileHandle (Private)

#pragma mark - Public methods

- (void)replaceBytesInRange:(NSRange)range withBytes:(const void *)bytes {
    [self performWithFileOffsetResetOffset:range.location
                                     block:^(NSFileHandle *__weak fh) {
                                         [fh writeData:[NSData dataWithBytes:bytes length:range.length]];
                                     }];
}

- (void)getBytes:(void *)result inRange:(NSRange)range {
    [self performWithFileOffsetResetOffset:range.location
                                     block:^(NSFileHandle *__weak fh) {
                                         NSData *data = [fh readDataOfLength:range.length];
                                         [data getBytes:result length:range.length];
                                     }];
}

- (void)getBytes:(void *)result atOffset:(const unsigned long long)offset length:(NSUInteger)length {
    [self performWithFileOffsetResetOffset:offset
                                     block:^(NSFileHandle *__weak fh) {
                                         NSData *data = [fh readDataOfLength:length];
                                         [data getBytes:result length:length];
                                     }];
}

- (uint32_t)unsignedInt32Atoffset:(const unsigned long long)offset {
    __block uint32_t result;
    [self performWithFileOffsetResetOffset:offset
                                     block:^(NSFileHandle *__weak fh) {
                                         NSData *data = [fh readDataOfLength:sizeof(uint32_t)];
                                         [data getBytes:&result length:sizeof(result)];
                                     }];
    return result;
}

#pragma mark - Private methods

- (void)performWithFileOffsetResetOffset:(const unsigned long long)offset
                                   block:(void (^)(NSFileHandle *__weak fh))block {
    NSFileHandle *__weak weakSelf = self;
    unsigned long long oldOffset = self.offsetInFile;
    [self seekToFileOffset:offset];
    block(weakSelf);
    [self seekToFileOffset:oldOffset];
}

@end
