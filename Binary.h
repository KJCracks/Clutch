//
//  Binary.h
//  Clutch
//
//  Created by Thomas Hedderwick on 04/09/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Application.h"

@interface Binary : NSObject

/* Properties */
@property (nonatomic, strong) NSString *binaryPath;
@property (nonatomic, strong) NSString *temporaryPath;
@property (nonatomic, strong) NSArray *archs;

@property (strong) Application *application;

/* Methods */
- (void)cleanUp;
- (NSArray *)getArches;
- (id)initWithApplication:(Application *)app;
- (void)injectBinary;
- (void)dump;

@end
