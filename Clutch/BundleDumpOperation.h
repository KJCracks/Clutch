//
//  BundleDumpOperation.h
//  Clutch
//
//  Created by Anton Titkov on 11.02.15.
//
//

NS_ASSUME_NONNULL_BEGIN

@class ClutchBundle;

@interface BundleDumpOperation : NSOperation

@property (nonatomic, assign, readonly) BOOL failed;

- (nullable instancetype)initWithBundle:(nullable ClutchBundle *)application NS_DESIGNATED_INITIALIZER;
+ (nullable instancetype)operationWithBundle:(nullable ClutchBundle *)application;

@end

NS_ASSUME_NONNULL_END
