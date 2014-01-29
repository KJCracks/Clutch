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
#import "Binary.h"

@implementation Install : NSObject 

- (instancetype)initWithIPA:(NSString*)ipaPath withBinary:(NSString*)binary
{
     if (self = [super init])
     {
         _ipaPath = ipaPath;
         _binaryPath = binary;
     }
    
    return self;
}

static NSString* generateUuidString()
{
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

-(void) installIPA
{
    BOOL exists = TRUE;
    
    while (exists == TRUE)
    {
        _installedPath = [NSString stringWithFormat:@"/var/mobile/Applications/%@", generateUuidString()];
    
        if (![[NSFileManager defaultManager] fileExistsAtPath:_installedPath isDirectory:YES])
        {
            exists = FALSE;
            break;
        }
    }
    
    DEBUG(@"location extract: %s\n", [_installedPath UTF8String]);
    
    ZipArchive* zip = [[ZipArchive alloc] init];
    [zip UnzipOpenFile:_ipaPath];
    [zip UnzipFileTo:_installedPath overWrite:YES];
    
    [zip release];
    
    NSString* binaryPath = [NSString stringWithFormat:@"%@/%@", _installedPath, _binaryPath];
    NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNumber numberWithShort:0775], NSFilePosixPermissions, nil];
    
    [[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:binaryPath error:nil];
    [attributes release];
    
    _binaryPath = [_installedPath stringByAppendingPathComponent:_binaryPath];
    DEBUG(@"final binary path %@", _binaryPath);
}

- (void)crackWithOutBinary:(NSString*)outbinary
{
    [[NSFileManager defaultManager] removeItemAtPath:outbinary error:nil];
    
    Binary* binary = [[Binary alloc] initWithBinary:_binaryPath];
    
    DEBUG(@"outbinary %@", outbinary);
    
    [binary crackBinaryToFile:outbinary error:nil];
    
    DEBUG(@"apparently crack was ok!?");
    
    [binary release];
    
    [[NSFileManager defaultManager] removeItemAtPath:_installedPath error:nil];
}

@end