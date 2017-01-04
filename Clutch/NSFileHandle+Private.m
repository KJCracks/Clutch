//
//  NSFileHandle+Private.m
//  Clutch
//
//  Created by Anton Titkov on 01.04.15.
//
//

#import "NSFileHandle+Private.h"

@implementation NSFileHandle (Private)

- (void)replaceBytesInRange:(NSRange)range withBytes:(const void *)bytes
{
    unsigned long long oldOffset = self.offsetInFile;
    
    [self seekToFileOffset:range.location];
    
    [self writeData:[NSData dataWithBytes:bytes length:range.length]];
    
    [self seekToFileOffset:oldOffset];
}

- (void)getBytes:(void *)result inRange:(NSRange)range
{
    unsigned long long oldOffset = self.offsetInFile;
    
    [self seekToFileOffset:range.location];
    
    NSData *data = [self readDataOfLength:range.length];
    
    [data getBytes:result length:range.length];
    
    [self seekToFileOffset:oldOffset];
}

- (void)getBytes:(void*)result atOffset:(NSUInteger)offset length:(NSUInteger)length
{
    unsigned long long oldOffset = self.offsetInFile;
    
    [self seekToFileOffset:offset];
    
    NSData *data = [self readDataOfLength:length];
    
    [data getBytes:result length:length];
    
    [self seekToFileOffset:oldOffset];
}

- (const void *)bytesAtOffset:(NSUInteger)offset length:(NSUInteger)size
{
    unsigned long long oldOffset = self.offsetInFile;
    
    [self seekToFileOffset:offset];
    
    const void * result;
    
    NSData *data = [self readDataOfLength:size];
    
    [data getBytes:&result length:size];
    
    [self seekToFileOffset:oldOffset];
    
    return result;
}

- (uint32_t)intAtOffset:(unsigned long long)offset
{
    unsigned long long oldOffset = self.offsetInFile;
    
    [self seekToFileOffset:offset];
    
    uint32_t result;
    
    NSData *data = [self readDataOfLength:sizeof(result)];
    
    [data getBytes:&result length:sizeof(result)];
    
    [self seekToFileOffset:oldOffset];
    
    return result;
}

@end
