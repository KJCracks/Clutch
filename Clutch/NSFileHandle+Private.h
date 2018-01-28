//
//  NSFileHandle+Private.h
//  Clutch
//
//  Created by Anton Titkov on 01.04.15.
//
//

NS_ASSUME_NONNULL_BEGIN

@interface NSFileHandle (Private)

/**
 Gets an unsigned integer at the given offset.
 @param offset File offset.
 @return Unsigned integer value.
 */
- (uint32_t)unsignedInt32Atoffset:(const unsigned long long)offset;
/**
 Replaces bytes given a range with new bytes.
 @param range Range.
 @param bytes Replacement data.
 */
- (void)replaceBytesInRange:(NSRange)range withBytes:(const void *)bytes;
/**
 Gets a fixed number of bytes at a given offset.
 @param result Buffer to write to.
 @param offset File offset.
 @param length Length of the buffer.
 */
- (void)getBytes:(void *)result atOffset:(const unsigned long long)offset length:(NSUInteger)length;
/**
 Gets a fixed number of a bytes at a given offset using a range structure.
 @param result Buffer to write to.
 @param range Range structure.
 */
- (void)getBytes:(void *)result inRange:(NSRange)range;

@end

NS_ASSUME_NONNULL_END
