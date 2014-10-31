//
//  Application.h
//  Clutch
//
//  Created by NinjaLikesCheez on 15/08/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#import <Foundation/Foundation.h>

#pragma mark - Application Object

@interface Application : NSObject

/* Properties */
@property (nonatomic, strong) NSString *container; // /private/var/mobile/Containers/Bundle/Application/$uuid/
@property (nonatomic, strong) NSString *binaryPath; // /private/var/mobile/Containers/Bundle/Application/$uuid/%appname.app/$binary
@property (nonatomic, strong) NSString *displayName; // $itemName
@property (nonatomic, strong) NSString *name; // $itemName
@property (nonatomic, strong) NSString *directoryPath; // /private/var/mobile/Containers/Bundle/Application/$uuid/$appname.app
@property (nonatomic, strong) NSString *realUniqueID; // $uuid
@property (nonatomic, strong) NSString *version; // $bundleVersion
@property (nonatomic, strong) NSString *shortVersion; // $shortVersionString
@property (nonatomic, strong) NSString *bundleID; // $applicationIdentifier
@property (nonatomic, strong) NSString *executableName; // $CFBundleExecutable
@property (nonatomic, strong) NSString *minimumOSVersion; // $minimumOSVersion
@property (nonatomic, strong) NSArray *plugins; // $plugInKitPlugins
@property (nonatomic) BOOL installed;

/* Methods */

@end

#pragma mark - Plugin Object

@interface Plugin : NSObject

/* Properties */
@property (nonatomic, strong) NSString *path;
@property (nonatomic, strong) NSString *executable;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *name;

@end

#pragma mark - Application Lister

@interface ApplicationLister : NSObject

/* Methods */
+ (NSArray *)applications;
+ (NSArray *)applicationListForiOS7;
+ (NSArray *)applicationListForiOS8;

@end
