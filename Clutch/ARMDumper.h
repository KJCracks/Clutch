//
//  ARMDumper.h
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "Dumper.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARMDumper : Dumper <BinaryDumpProtocol, FrameworkBinaryDumpProtocol>
@end

NS_ASSUME_NONNULL_END
