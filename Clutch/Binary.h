//
//  Binary.h
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "BundleDumpOperation.h"

NS_ASSUME_NONNULL_BEGIN

@class ClutchBundle;

@interface Binary : NSObject

@property (nonatomic, readonly) BOOL hasRestrictedSegment;
@property (nonatomic, readonly) BundleDumpOperation *dumpOperation;
@property (nonatomic, readonly) NSString *workingPath;
@property (nonatomic, readonly) NSString *binaryPath;
@property (nonatomic, readonly) NSString *sinfPath;
@property (nonatomic, readonly) NSString *supfPath;
@property (nonatomic, readonly) NSString *suppPath;
@property (nonatomic, readonly) NSString *frameworksPath;
@property (nonatomic, readonly) BOOL isFAT;
@property (nonatomic, readonly) BOOL hasARMSlice;
@property (nonatomic, readonly) BOOL hasARM64Slice;
@property (nonatomic, readonly) BOOL hasMultipleARMSlices;
@property (nonatomic, readonly) BOOL hasMultipleARM64Slices;

- (nullable instancetype)initWithBundle:(nullable ClutchBundle *)bundle NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
