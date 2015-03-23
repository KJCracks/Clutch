//
//  ZipOperation.h
//  Clutch
//
//  Created by Anton Titkov on 11.02.15.
//
//

#import <Foundation/Foundation.h>

#ifdef DEBUG
#define PRINT_ZIP_LOGS 0
#endif

@class ClutchBundle;

@interface ZipOperation : NSOperation

- (instancetype)initWithApplication:(ClutchBundle *)clutchBundle;

@end
