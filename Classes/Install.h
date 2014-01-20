//
//  Install.h
//  Clutch
//


#import <Foundation/Foundation.h>
#import "MobileInstallation.h"

@interface Install : NSObject
{
    NSString* _ipaPath;
    NSString* _installedPath;
    NSString* _binaryPath;
}

- (instancetype)initWithIPA:(NSString*)ipaPath withBinary:(NSString*)binary;
- (void)installIPA;
- (void)crackWithOutBinary:(NSString*)outbinary;


@end
