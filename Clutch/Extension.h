//
//  Extension.h
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "ClutchBundle.h"

NS_ASSUME_NONNULL_BEGIN

@class Application;

@interface Extension : ClutchBundle

@property (readonly) BOOL isWatchKitExtension;

@end

NS_ASSUME_NONNULL_END
