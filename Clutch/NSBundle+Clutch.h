//
//  NSBundle+Clutch.h
//  Clutch
//
//  Created by Anton Titkov on 20.04.15.
//
//

#import <Foundation/Foundation.h>

@interface NSBundle (Clutch)

@property (nonatomic, retain) NSString *clutchBID;

- (NSString *)bundleIdentifier;

@end
