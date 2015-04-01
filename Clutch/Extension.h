//
//  Extension.h
//  Clutch
//
//  Created by Anton Titkov on 10.02.15.
//
//

#import <Foundation/Foundation.h>
#import "ClutchBundle.h"

@class Application;

NS_CLASS_AVAILABLE_IOS(8_0)
@interface Extension : ClutchBundle

@property (readonly) BOOL isWatchKitExtension;

@end
