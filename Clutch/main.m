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
#import <sys/time.h>

int diff_ms(struct timeval t1, struct timeval t2);

int diff_ms(struct timeval t1, struct timeval t2)
{
    return (int)((((t1.tv_sec - t2.tv_sec) * 1000000) +
                  (t1.tv_usec - t2.tv_usec)) / 1000);
}

void listApps();
void listApps() {
    ApplicationsManager *_manager = [ApplicationsManager sharedInstance];
    
    NSArray *installedApps = [_manager installedApps].allValues;
    printf("Installed apps:\n");
    
    int count;
    NSString* space;
    for (Application *_app in installedApps) {
        //gbprintln(@"%u) %@\n",(unsigned int)([installedApps indexOfObject:_app]+1),_app);
        
        count = [installedApps indexOfObject:_app] + 1;
        if (count < 10) {
            space = @"  ";
        }
        else if (count < 100) {
            space = @" ";
        }
        printf("\033[1;3%um %u: %s%s <%s>\033[0m\n", 5 + ((count) % 2), count, space.UTF8String ,[_app.displayName UTF8String], [_app.bundleIdentifier UTF8String]);
    }
    exit(0);
}

int main (int argc, const char * argv[])
{
    

    @autoreleasepool
    {
        // yo
        if (SYSTEM_VERSION_LESS_THAN(NSFoundationVersionNumber_iOS_6_0)) {
            
            gbprintln(@"You need iOS 6.0+ to use Clutch %@",CLUTCH_VERSION);
            
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
            
            // :P
            //listApps();
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
                listApps();
            }
            
            else if ([option isEqualToString:@"fmwk-dump"]) {
                
                NSArray *arguments = [NSProcessInfo processInfo].arguments;
                
                if (([arguments[1]isEqualToString:@"--fmwk-dump"]||[arguments[1]isEqualToString:@"-f"]) && (arguments.count == 9)) {
                    
                    FrameworkLoader *fmwk = [FrameworkLoader new];
                                        
                    fmwk.binPath = arguments[2];
                    fmwk.dumpPath = arguments[3];
                    fmwk.encryptionInfoCommand = [arguments[4]intValue];
                    fmwk.pages = [arguments[5]intValue];
                    fmwk.ncmds = [arguments[6]intValue];
                    fmwk.offset = [arguments[7]intValue];
                    fmwk.bID = arguments[8];
                    
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
        
        NSDictionary *_installedApps = [_appsManager _allCachedApplications];
        NSArray* _installedArray = _installedApps.allValues;
        
        NSArray* selections = [_selectedBundleID componentsSeparatedByString:@" "];
        
        for (NSString* selection in selections) {
            int key;
            struct timeval start, end;
            //NSLog(@"selection wow %@ ", selection);
            
            if (!(key = [selection intValue])) {
                gbprintln(@"Please enter a proper number.");
                exit(0);
            }
            
            key = key - 1;
            
            if (key > [_installedArray count]) {
                gbprintln(@"Couldn't find app with corresponding number!?!");
                exit(0);
            }
            
            Application *_selectedApp = [_installedArray objectAtIndex:key];
            
            if (!_selectedApp) {
                gbprintln(@"Couldn't find installed app");
                exit(0);
            }
            
            printf("\033[1;34mNow dumping %s\033[0m\n\n", _selectedApp.bundleIdentifier.UTF8String);
            gettimeofday(&start, NULL);
            [_selectedApp dumpToDirectoryURL:nil onlyBinaries:[_selectedOption isEqualToString:@"binary-dump"]];
            
            CFRunLoopRun();
            gettimeofday(&end, NULL);
            int dif = diff_ms(end,start);
            float sec = ((dif + 500.0f) / 1000.0f);
            gbprintln(@"Finished dumping %@ in %0.1f seconds", _selectedApp.bundleIdentifier, sec);
            
            
            
            //NSLog(@"you shouldnt be there pal. exiting with -1 code");
            //return -1;
        }
        
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


