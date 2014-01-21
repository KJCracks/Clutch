//
//  CRC32.m
//  yopainstalld
//


#import "CRC32.h"

NSString* checksumOfFile(NSURL* fileURL) {
    // Declare needed variables and buffers
    CFStringRef result = NULL;
    CFReadStreamRef readStream = NULL;
    unsigned char digest[CC_CRC32_DIGEST_LENGTH];
    char hash[2 * CC_CRC32_DIGEST_LENGTH + 1];
    int chunkSizeForReadingData = 4096;
    
    CC_CRC32_CTX ctx;
    
    // Get the file URL
    
    // Create and open the read stream
    readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault,
                                            (CFURLRef)fileURL);
    
    bool didSucceed = (bool)CFReadStreamOpen(readStream);
    
    if (!didSucceed) {
        NSLog(@"could not open stream, huh!?");
    }
    
    // Initialize the hash object
    CC_CRC32_Init(&ctx);
    
    // Feed the data
    bool hasMoreData = true;
    while (hasMoreData) {
        uint8_t buffer[chunkSizeForReadingData];
        CFIndex readBytesCount = CFReadStreamRead(readStream,
                                                  (UInt8 *)buffer,
                                                  (CFIndex)sizeof(buffer));
        if (readBytesCount == -1) break;
        if (readBytesCount == 0) {
            hasMoreData = false;
            continue;
        }
        CC_CRC32_Update(&ctx, (const void*)buffer, (uint32_t)readBytesCount);
    }
    
    // Compute the digest
    CC_CRC32_Final(digest, &ctx);
    
    // Compute the string result
    for (size_t i = 0; i < chunkSizeForReadingData; ++i) {
        snprintf(hash + (2 * i), 3, "%02x", (int)(digest[i]));
    }
    
    result = CFStringCreateWithCString(kCFAllocatorDefault, 
                                       (const char *)hash, 
                                       kCFStringEncodingUTF8);
    return (NSString*)result;
}