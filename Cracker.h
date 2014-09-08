//
//  Cracker.h
//  Clutch
//
//  Created by NinjaLikesCheez on 04/09/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Application.h"
#import "mach/machine.h"

@interface Cracker : NSObject

+ (id)sharedSingleton;

- (BOOL)crackApplication:(Application *)application;
- (BOOL)performPreflightChecks:(Application *)application;

@end
