//
//  FinalizeDumpOperation.h
//  Clutch
//
//  Created by Anton Titkov on 12.02.15.
//
//

NS_ASSUME_NONNULL_BEGIN

@class Application;

@interface FinalizeDumpOperation : NSOperation

@property (nonatomic, assign) BOOL onlyBinaries;
@property (nonatomic, assign) NSUInteger expectedBinariesCount;

- (nullable instancetype)initWithApplication:(nullable Application *)application NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
