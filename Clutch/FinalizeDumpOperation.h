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

@property (assign) BOOL onlyBinaries;
@property (assign) NSInteger expectedBinariesCount;

- (instancetype)initWithApplication:(Application *)application;

@end
