//
//  main.m
//  Clutch
//
//  Created by Anton Titkov on 09.02.15.
//  Copyright (c) 2015 AppAddict. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GBCli.h"
#import "ApplicationsManager.h"

int main (int argc, const char * argv[])
{

    @autoreleasepool
    {	
    	// insert code here...
        
        
        GBOptionsHelper *options = [[GBOptionsHelper alloc] init];
        options.applicationVersion = ^{ return @"2.0"; };
        options.printHelpHeader = ^{ return @"Usage: %APPNAME [OPTIONS]"; };
        //options.printHelpFooter = ^{ return @"Thanks to everyone for their help..."; };
        
        [options registerOption:'d' long:@"dump" description:@"Dump specified bundleID" flags:GBValueRequired];
        [options registerOption:'i' long:@"print-installed" description:@"Print installed application" flags:GBValueNone];
        [options registerOption:0 long:@"version" description:@"Display version and exit" flags:GBValueNone|GBOptionNoPrint];
        [options registerOption:'?' long:@"help" description:@"Display this help and exit" flags:GBValueNone|GBOptionNoPrint];
        
        if (argc == 1) {
            [options printHelp];
            exit(0);
        }
        
        GBCommandLineParser *parser = [[GBCommandLineParser alloc] init];
        [parser registerOptions:options];
        [parser parseOptionsWithArguments:(char **)argv count:argc block:^(GBParseFlags flags, NSString *option, id value, BOOL *stop) {
            
            if ([option isEqualToString:@"help"]) {
                [options printHelp];
                exit(0);
            }else if ([option isEqualToString:@"version"]) {
                [options printVersion];
                exit(0);
            }else if ([option isEqualToString:@"print-installed"]) {
                ApplicationsManager *_manager = [ApplicationsManager sharedInstance];
                
                NSArray *installedApps = [_manager installedApps];
                printf("Installed apps:\n");
                for (Application *_app in installedApps) {
                    //printf("%u) %s\n",(unsigned int)([installedApps indexOfObject:_app]+1),_app.bundleIdentifier.UTF8String);
                    gbprintln(@"%u) %@ %@\n",(unsigned int)([installedApps indexOfObject:_app]+1),_app.bundleIdentifier,_app);
                }
                exit(0);
            }
            
            switch (flags) {
                case GBParseFlagUnknownOption:
                    printf("Unknown command line option %s, try --help!\n", [option UTF8String]);
                    break;
                case GBParseFlagMissingValue:
                    printf("Missing value for %s option, try --help!\n", [option UTF8String]);
                    break;
                case GBParseFlagOption:
                    // do something with 'option' and its 'value'
                    break;
                case GBParseFlagArgument:
                    // do something with argument 'value'
                    break;
            }
        }];
        
        
        
    }
	return 0;
}

