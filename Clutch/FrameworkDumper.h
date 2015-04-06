//
//  FrameworkDumper.h
//  Clutch
//
//  Created by Anton Titkov on 02.04.15.
//
//

#import "Dumper.h"
#import "CPDistributedMessanging.h"

@interface FrameworkDumper : Dumper <FrameworkBinaryDumpProtocol> {
    CPDistributedMessagingCenter* center;
}

@end
