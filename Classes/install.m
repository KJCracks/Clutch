//
//  install.m
//  Clutch
//
//  Created by Terence Tan on 15/10/13.
//
//

#import "install.h"
#import <Foundation/Foundation.h>
#import "ZipArchive.h"
#import "crack.h"

// return a new autoreleased UUID string
NSString* generateUuidString() {
    // create a new UUID which you own
    CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
    
    // create a new CFStringRef (toll-free bridged to NSString)
    // that you own
    NSString *uuidString = (NSString *)CFUUIDCreateString(kCFAllocatorDefault, uuid);
    
    // transfer ownership of the string
    // to the autorelease pool
    [uuidString autorelease];
    
    // release the UUID
    CFRelease(uuid);
    
    return uuidString;
}

NSString* install_and_crack(NSString* ipa, NSString* binary, NSString* outbinary) {
   // printf("hello tere\n");
    NSLog(@"swag %@ %@ %@", ipa, binary, outbinary);
    bool exists = TRUE;
    NSString* location;
    while (exists == TRUE) {
        location = [NSString stringWithFormat:@"/var/mobile/Applications/%@", generateUuidString()];
        if (![[NSFileManager defaultManager] fileExistsAtPath:location isDirectory:YES]) {
            exists = FALSE;
            break;
        }
    }
    printf("location extract: %s\n", [location UTF8String]);
    ZipArchive* zip = [[ZipArchive alloc] init];
    [zip UnzipOpenFile:ipa];
    [zip UnzipFileTo:location overWrite:YES];
    
    NSString* error;
    NSString* binaryPath = [NSString stringWithFormat:@"%@/%@", location, binary];
    NSLog(@"binary path %@", binaryPath);
    NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithShort:0775], NSFilePosixPermissions, nil];
    
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:binaryPath error:nil];
    NSLog(@"setted attributes!");
    crack_binary(binaryPath, outbinary, &error);
    [[NSFileManager defaultManager] removeItemAtPath:location error:nil];
    return location;
}