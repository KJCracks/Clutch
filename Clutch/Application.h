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

@interface Application : ClutchBundle

@property (nonatomic, readonly) BOOL hasAppleWatchApp; // YES if contains watchOS 2 compatible application
@property (nonatomic, readonly) BOOL isAppleWatchApp; // only for Apple Watch apps that support watchOS 2 or newer (armv7k)

@property (nonatomic, retain, readonly) NSArray *extensions;
@property (nonatomic, retain, readonly) NSArray *frameworks;
@property (nonatomic, retain, readonly) NSArray *watchOSApps;

- (BOOL)dumpToDirectoryURL:(NSURL *)directoryURL onlyBinaries:(BOOL)yrn;

@end
