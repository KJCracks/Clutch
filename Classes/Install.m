//
//  Install.m
//  Clutch
//
//  Created by Terence Tan on 8/1/14.
//
//

#import "Install.h"
#import "MobileInstallation.h"
#import "ZipArchive.h"
#import "CABinary.h"

@implementation Install : NSObject 

- (instancetype)initWithIPA:(NSString*)ipaPath withBinary:(NSString*)binary{
     if (self = [super init]) {
         _ipaPath = ipaPath;
         _binaryPath = binary;
     }
    return self;
}

static NSString* generateUuidString() {
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

-(void) installIPA {
    bool exists = TRUE;;
    while (exists == TRUE) {
        _installedPath = [NSString stringWithFormat:@"/var/mobile/Applications/%@", generateUuidString()];
        if (![[NSFileManager defaultManager] fileExistsAtPath:_installedPath isDirectory:YES]) {
            exists = FALSE;
            break;
        }
    }
    printf("location extract: %s\n", [_installedPath UTF8String]);
    ZipArchive* zip = [[ZipArchive alloc] init];
    [zip UnzipOpenFile:_ipaPath];
    [zip UnzipFileTo:_installedPath overWrite:YES];
    
    NSString* binaryPath = [NSString stringWithFormat:@"%@/%@", _installedPath, _binaryPath];
    NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithShort:0775], NSFilePosixPermissions, nil];
    
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:binaryPath error:nil];
    printf("setted attributes!\n");
}
-(void) crackWithOutBinary:(NSString*)outbinary {
    CABinary* binary = [[CABinary alloc] initWithBinary:_binaryPath];
    DebugLog(@"outbinary %@", outbinary);
    [binary crackBinaryToFile:outbinary error:nil];
    DebugLog(@"apparently crack was ok!?");
}

@end
