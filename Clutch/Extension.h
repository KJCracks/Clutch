//
//  Extension.h
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import "ClutchBundle.h"
#import <Foundation/Foundation.h>

@class Application;

NS_CLASS_AVAILABLE_IOS(8_0)
@interface Extension : ClutchBundle

@property (readonly) BOOL isWatchKitExtension;

@end
