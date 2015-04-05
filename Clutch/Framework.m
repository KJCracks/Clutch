//
//  Framework.m
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "Framework.h"
#import "Device.h"

@implementation Framework

- (instancetype)initWithBundleInfo:(NSDictionary *)info
{
    if (self = [super initWithBundleInfo:info]) {
        
        
    }
    return self;
}

- (void)prepareForDump
{
    [super prepareForDump];
    
    NSMutableData *data = [NSMutableData dataWithContentsOfFile:self.executable.binaryPath];
    
    thin_header headers[4];
    uint32_t numHeaders = 0;
    
    headersFromBinary(headers, data, &numHeaders);

    for (int i = 0; i < numHeaders; i++) {
        thin_header _thinHeader = headers[i];
        insertRPATHIntoBinary(self.executable.binaryPath.stringByDeletingLastPathComponent, data, _thinHeader);
    }
    
    [data writeToFile:self.executable.binaryPath atomically:YES];
    
}

- (NSString *)zipFilename
{
    return self.parentBundle.zipFilename;
}

- (NSString *)zipPrefix
{
    return [@"Payload" stringByAppendingPathComponent:[self.bundleContainerURL.path stringByReplacingOccurrencesOfString:self.parentBundle.bundleContainerURL.path withString:@""]];
}

- (NSURL *)enumURL
{
    return self.bundleURL;
}

- (NSString *)workingPath
{
    return self.parentBundle.workingPath;
}

@end
