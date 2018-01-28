//
//  ZipOperation.h
//  Clutch
//
//  Created by Anton Titkov on 11.02.15.
//
//

NS_ASSUME_NONNULL_BEGIN

@class ClutchBundle;

@interface ZipOperation : NSOperation

- (nullable instancetype)initWithApplication:(nullable ClutchBundle *)clutchBundle NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
