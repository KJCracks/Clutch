//
//  Cracker.m
//  Clutch
//
//  Created by NinjaLikesCheez on 04/09/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#import "Cracker.h"
#import "Application.h"
#import "Binary.h"

#import "mach/machine.h"
#import <mach-o/dyld.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>


@implementation Cracker

+ (id)sharedSingleton
{
    static Cracker *sharedSingleton = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        sharedSingleton = [[self alloc] init];
    });
    
    return sharedSingleton;
}

- (id)init
{
    if (self = [super init])
    {
        /* Properties */
    }
    
    return self;
}

- (BOOL)crackApplication:(Application *)application
{
    BOOL success = [self performPreflightChecks:application];
    
    if (success)
    {
        
        return EXIT_SUCCESS;
    }
    
    return EXIT_FAILURE;
}

- (BOOL)performPreflightChecks:(Application *)application
{
    /* Check binary */
    BOOL exsists = [[NSFileManager defaultManager] fileExistsAtPath:application.binaryPath];
    
    if (exsists)
    {
        printf("Binary found: %s\n", application.binaryPath.UTF8String);
        Binary *binary = [[Binary alloc] initWithApplication:application];
        
        [binary dump];
        
        
        [binary cleanUp];
        [binary release];
        return EXIT_SUCCESS;
    }
    else
    {
        printf("Cannot find binary at path: %s", application.binaryPath.UTF8String);
    }
    return EXIT_FAILURE;
}

@end