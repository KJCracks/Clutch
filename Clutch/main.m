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
#import "sha1.h"
#import "FrameworkLoader.h"

int main (int argc, const char * argv[])
{

    @autoreleasepool
    {
        // yo
        if (SYSTEM_VERSION_LESS_THAN(NSFoundationVersionNumber_iOS_6_0)) {
            
            gbprintln(@"You need iOS 6.0+ to use Clutch 2");
            
            return 0;
        }

        GBOptionsHelper *options = [[GBOptionsHelper alloc] init];
        options.applicationVersion = ^{ return CLUTCH_VERSION; };
        options.printHelpHeader = ^{ return @"Usage: %APPNAME [OPTIONS]"; };
        //options.printHelpFooter = ^{ return @"Thanks to everyone for their help..."; };
        
        [options registerOption:'f' long:@"fmwk-dump" description:@"Only dump binary files from specified bundleID" flags:GBValueRequired|GBOptionNoPrint|GBOptionInvisible];
        [options registerOption:'b' long:@"binary-dump" description:@"Only dump binary files from specified bundleID" flags:GBValueRequired|GBOptionNoPrint];
        [options registerOption:'d' long:@"dump" description:@"Dump specified bundleID into .ipa file" flags:GBValueRequired|GBOptionNoPrint];
        [options registerOption:'i' long:@"print-installed" description:@"Print installed applications" flags:GBValueNone|GBOptionNoPrint];
        [options registerOption:0 long:@"clean" description:@"Clean /var/tmp/clutch directory" flags:GBValueNone|GBOptionNoPrint];
        [options registerOption:0 long:@"version" description:@"Display version and exit" flags:GBValueNone|GBOptionNoPrint];
        [options registerOption:'?' long:@"help" description:@"Display this help and exit" flags:GBValueNone|GBOptionNoPrint];
        
        if (argc == 1) {
            [options printHelp];
            exit(0);
        }
    
        __block NSString * _selectedOption, * _selectedBundleID;
        
        GBCommandLineParser *parser = [[GBCommandLineParser alloc] init];
        [parser registerOptions:options];
        [parser parseOptionsWithArguments:(char **)argv count:argc block:^(GBParseFlags flags, NSString *option, id value, BOOL *stop) {
            
            if ([option isEqualToString:@"help"]) {
                [options printHelp];
                exit(0);
            }else if ([option isEqualToString:@"version"]) {
                [options printVersion];
                exit(0);
            }else if ([option isEqualToString:@"clean"]) {
                [[NSFileManager defaultManager]removeItemAtPath:@"/var/tmp/clutch" error:nil];
                [[NSFileManager defaultManager]createDirectoryAtPath:@"/var/tmp/clutch" withIntermediateDirectories:YES attributes:nil error:nil];
                exit(0);
            }else if ([option isEqualToString:@"print-installed"]) {
                ApplicationsManager *_manager = [ApplicationsManager sharedInstance];
                
                NSArray *installedApps = [_manager installedApps].allValues;
                printf("Installed apps:\n");
                for (Application *_app in installedApps) {
                    gbprintln(@"%u) %@\n",(unsigned int)([installedApps indexOfObject:_app]+1),_app);
                }
                exit(0);
            }else if ([option isEqualToString:@"print-installed"]) {
                ApplicationsManager *_manager = [ApplicationsManager sharedInstance];
                
                NSArray *installedApps = [_manager installedApps].allValues;
                printf("Installed apps:\n");
                for (Application *_app in installedApps) {
                    gbprintln(@"%u) %@\n",(unsigned int)([installedApps indexOfObject:_app]+1),_app);
                }
                exit(0);
            }else if ([option isEqualToString:@"fmwk-dump"]) {
                
                NSArray *arguments = [NSProcessInfo processInfo].arguments;
                
                if (([arguments[1]isEqualToString:@"--fmwk-dump"]||[arguments[1]isEqualToString:@"-f"]) && (arguments.count == 8)) {
                    
                    FrameworkLoader *fmwk = [FrameworkLoader new];
                                        
                    fmwk.binPath = arguments[2];
                    fmwk.dumpPath = arguments[3];
                    fmwk.encryptionInfoCommand = [arguments[4]intValue];
                    fmwk.pages = [arguments[5]intValue];
                    fmwk.ncmds = [arguments[6]intValue];
                    fmwk.offset = [arguments[7]intValue];

                    BOOL result = [fmwk dumpBinary];
                    
                    if (result) {
                        exit(0);
                    }
                    
                }
                
                exit(-1);
            }
            
            switch (flags) {
                case GBParseFlagUnknownOption:
                    printf("Unknown command line option %s, try --help!\n", [option UTF8String]);
                    break;
                case GBParseFlagMissingValue:
                    printf("Missing value for %s option, try --help!\n", [option UTF8String]);
                    break;
                case GBParseFlagOption:

                    _selectedOption = option;
                    
                    if ([_selectedOption isEqualToString:@"dump"]||[_selectedOption isEqualToString:@"binary-dump"]) {
                        
                        _selectedBundleID = [value copy];
                    }
                    
                    break;
                case GBParseFlagArgument:
                    //NSLog(@"GBParseFlagArgument %@",value);
                    break;
            }
        }];
        
        if (!_selectedBundleID) {
            [options printHelp];
            exit(0);
        }
        
        if (!([_selectedOption isEqualToString:@"dump"]||[_selectedOption isEqualToString:@"binary-dump"]))
            return -1;
        
        ApplicationsManager *_appsManager = [ApplicationsManager sharedInstance];
        
        NSDictionary *_installedApps = [_appsManager installedApps];
        
        Application *_selectedApp = _installedApps[_selectedBundleID];
        
        if (!_selectedApp) {
            gbprintln(@"Couldn't find installed app with bundle identifier: %@",_selectedBundleID);
            exit(0);
        }

        [_selectedApp dumpToDirectoryURL:nil onlyBinaries:[_selectedOption isEqualToString:@"binary-dump"]];
        
        CFRunLoopRun();
        
        NSLog(@"you shouldnt be there pal. exiting with -1 code");
        return -1;

        
    }
	return 0;
}

void sha1(uint8_t *hash, uint8_t *data, size_t size);

void sha1(uint8_t *hash, uint8_t *data, size_t size) {
    SHA1Context context;
    SHA1Reset(&context);
    SHA1Input(&context, data, (unsigned)size);
    SHA1Result(&context, hash);
}
