//
//  FrameworkDumper.h
//  Clutch
//
//  Created by Anton Titkov on 02.04.15.
//
//

#import "Dumper.h"

NS_ASSUME_NONNULL_BEGIN

@interface FrameworkDumper : Dumper <FrameworkBinaryDumpProtocol, BinaryDumpProtocol>
@end

NS_ASSUME_NONNULL_END
