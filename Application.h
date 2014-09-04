//
//  Application.h
//  Clutch
//
//  Created by Thomas Hedderwick on 15/08/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Application : NSObject

/* Properties */
@property (nonatomic, strong) NSString *container;
@property (nonatomic, strong) NSString *displayName;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *directory;
@property (nonatomic, strong) NSString *realUniqueID;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *bundleID;
@property (nonatomic, strong) NSString *executableName;
@property (nonatomic, strong) NSString *minimumOSVersion;
@property (nonatomic, strong) NSString *sinf;
@property (nonatomic, strong) NSString *supp;
@property (nonatomic, strong) NSString *supf;

//@property (nonatomic, strong) NSData *sinf;
//@property (nonatomic, strong) NSData *supp;
//@property (nonatomic, strong) NSData *supf;


/* Methods */

@end

@interface ApplicationLister : NSObject

/* Methods */
+ (NSArray *)applications;

@end