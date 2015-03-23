//
//  Dumper.h
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "BinaryDumpProtocol.h"

@interface Dumper : NSObject
+ (instancetype)sharedInstance;
- (ArchCompatibility)compatibilityModeWithCurrentDevice;
@end
