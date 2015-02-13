//
//  FinalizeDumpOperation.h
//  Clutch
//
//  Created by Anton Titkov on 12.02.15.
//
//

#import <Foundation/Foundation.h>

@class Application;

@interface FinalizeDumpOperation : NSOperation

- (instancetype)initWithApplication:(Application *)application;

@end
