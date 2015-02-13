//
//  Application.h
//  Clutch
//
//  Created by Anton Titkov on 09.02.2015.
//
//

#import <Foundation/Foundation.h>
#import "ClutchBundle.h"
#import "Extension.h"
#import "Framework.h"

@class Application;

@protocol ApplicationDelegate <NSObject>

- (void)crackingProcessStarted:(Application*)app;
- (void)application:(Application *)app crackingProcessStatusChanged:(NSString *)status progress:(float)progress;
- (void)crackingProcessFinished:(Application *)app;

@end

@interface Application : ClutchBundle

@property (readonly) NSArray *extensions;
@property (readonly) NSArray *frameworks;

@end
