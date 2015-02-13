//
//  Binary.h
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import <Foundation/Foundation.h>
#import "BundleDumpOperation.h"

@class ClutchBundle;

@interface Binary : NSObject

@property (readonly) BundleDumpOperation *dumpOperation;
@property (readonly) NSString *workingPath;
@property (readonly) NSString *binaryPath;
@property (readonly) NSString *sinfPath;
@property (readonly) NSString *supfPath;
@property (readonly) NSString *suppPath;

@property (readonly) BOOL hasARMSlice;
@property (readonly) BOOL hasARM64Slice;

- (instancetype)initWithBundle:(ClutchBundle *)bundle;

@end
