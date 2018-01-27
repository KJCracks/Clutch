//
//  BundleDumpOperation.h
//  Clutch
//
//  Created by Anton Titkov on 11.02.15.
//
//

@class ClutchBundle;

@interface BundleDumpOperation : NSOperation

@property (nonatomic, assign, readonly) BOOL failed;

- (instancetype)initWithBundle:(ClutchBundle *)application;
+ (instancetype)operationWithBundle:(ClutchBundle *)application;

@end
