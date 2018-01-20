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

@property (nonatomic, assign) BOOL onlyBinaries;
@property (nonatomic, assign) NSUInteger expectedBinariesCount;

- (instancetype)initWithApplication:(Application *)application;

@end
