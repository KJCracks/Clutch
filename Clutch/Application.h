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

@property (readonly) BOOL hasAppleWatchApp;
@property (readonly) BOOL isAppleWatchApp; // only for Apple Watch apps that support watchOS 2 or newer (armv7k)

@property (readonly) NSArray *extensions;
@property (readonly) NSArray *frameworks;
@property (readonly) NSArray *watchOSApps;

- (void)dumpToDirectoryURL:(NSURL *)directoryURL onlyBinaries:(BOOL)yrn;

@end
