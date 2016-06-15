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
#import "ClutchPrint.h"

int diff_ms(struct timeval t1, struct timeval t2)
{
    return (int)((((t1.tv_sec - t2.tv_sec) * 1000000) +
                  (t1.tv_usec - t2.tv_usec)) / 1000);
}

void listApps();
void listApps() {
    ApplicationsManager *_manager = [[ApplicationsManager alloc] init];
    
    NSArray *installedApps = [_manager installedApps].allValues;
    [[ClutchPrint sharedInstance] print:@"Installed apps:"];
    
    int count;
    NSString *space;
    for (Application *_app in installedApps)
    {
        count = [installedApps indexOfObject:_app] + 1;
        if (count < 10)
        {
            space = @"  ";
        }
        else if (count < 100)
        {
            space = @" ";
        }
        
        ClutchPrinterColor color;
        if (count % 2 == 0)
        {
            color = ClutchPrinterColorPurple;
        }
        else
        {
            color = ClutchPrinterColorPink;
        }
        
        [[ClutchPrint sharedInstance] printColor:color format:@"%d: %@%@ <%@>", count, space, _app.displayName, _app.bundleIdentifier];
    }
    
    exit(0);
}

int main (int argc, const char * argv[])
{
    

    @autoreleasepool
    {

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
        [options registerOption:'n' long:@"no-color" description:@"Print with colors disabled" flags:GBValueNone|GBOptionNoPrint];
        [options registerOption:'v' long:@"verbose" description:@"Print verbose messages" flags:GBValueNone|GBOptionNoPrint];
        
        if (argc == 1) {
            [options printHelp];
            exit(0);
            
            // :P
            //listApps();
        }
    
        __block NSString * _selectedOption, * _selectedBundleID;
        __block ClutchPrinterColorLevel colorLevel = ClutchPrinterColorLevelFull;
        __block ClutchPrinterVerboseLevel verboseLevel = ClutchPrinterVerboseLevelNone;
        
        
        GBCommandLineParser *parser = [[GBCommandLineParser alloc] init];
        [parser registerOptions:options];
        [parser parseOptionsWithArguments:(char **)argv count:argc block:^(GBParseFlags flags, NSString *option, id value, BOOL *stop) {
            
            
            if ([option isEqualToString:@"no-color"])
            {
                //[[ClutchPrint sharedInstance] setColorLevel:ClutchPrinterColorLevelNone];
                colorLevel = ClutchPrinterColorLevelNone;
            }
            else if ([option isEqualToString:@"verbose"])
            {
                //[[ClutchPrint sharedInstance] setVerboseLevel:ClutchPrinterVerboseLevelDeveloper];
                verboseLevel = ClutchPrinterVerboseLevelFull;
            }

            
            if ([option isEqualToString:@"help"])
            {
                [options printHelp];
                exit(0);
            }
            else if ([option isEqualToString:@"version"])
            {
                [options printVersion];
                exit(0);
            }
            else if ([option isEqualToString:@"clean"])
            {
                [[NSFileManager defaultManager]removeItemAtPath:@"/var/tmp/clutch" error:nil];
                [[NSFileManager defaultManager]createDirectoryAtPath:@"/var/tmp/clutch" withIntermediateDirectories:YES attributes:nil error:nil];
                exit(0);
            }
            else if ([option isEqualToString:@"print-installed"])
            {
                listApps();
            }
            
            else if ([option isEqualToString:@"fmwk-dump"])
            {
                
                NSArray *arguments = [NSProcessInfo processInfo].arguments;
                
                if (([arguments[1]isEqualToString:@"--fmwk-dump"]||[arguments[1]isEqualToString:@"-f"]) && (arguments.count == 13))
                {
                    
                    FrameworkLoader *fmwk = [FrameworkLoader new];
                                        
                    fmwk.binPath = arguments[2];
                    fmwk.dumpPath = arguments[3];
                    fmwk.pages = [arguments[4]intValue];
                    fmwk.ncmds = [arguments[5]intValue];
                    fmwk.offset = [arguments[6]intValue];
                    fmwk.bID = arguments[7];
                    fmwk.hashOffset = [arguments[8] intValue];
                    fmwk.codesign_begin = [arguments[9] intValue];
                    fmwk.cryptsize = [arguments[10] intValue];
                    fmwk.cryptoff = [arguments[11] intValue];
                    fmwk.cryptlc_offset = [arguments[12] intValue];
                    fmwk.dumpSize = fmwk.cryptoff + fmwk.cryptsize;
                    
                    
                    BOOL result = [fmwk dumpBinary];
                   
                    if (result)
                    {
                        [[ClutchPrint sharedInstance] printColor:ClutchPrinterColorPurple format:@"Successfully dumped framework!"];
                        exit(0);
                    }
                    else {
                        [[ClutchPrint sharedInstance] printColor:ClutchPrinterColorPurple format:@"Failed to dumped framework! :("];
                        exit(-2);
                    }
                    
                }
                
                exit(-1);
            }
            
            switch (flags)
            {
                case GBParseFlagUnknownOption:
                    [[ClutchPrint sharedInstance] print:@"Unknown command line option %@, try --help!", option];
                    break;
                case GBParseFlagMissingValue:
                    [[ClutchPrint sharedInstance] print:@"Missing value for %@ option, try --help!", option];
                    break;
                case GBParseFlagOption:

                    _selectedOption = option;
                    
                    if ([_selectedOption isEqualToString:@"dump"]||[_selectedOption isEqualToString:@"binary-dump"]) {
                        
                        _selectedBundleID = [value copy];
                    }
                    
                    break;
                case GBParseFlagArgument:
                    break;
            }
        }];
        
        [[ClutchPrint sharedInstance] setColorLevel:colorLevel];
        [[ClutchPrint sharedInstance] setVerboseLevel:verboseLevel];
    
        if (!_selectedBundleID)
        {
            [options printHelp];
            exit(0);
        }
        
        if (!([_selectedOption isEqualToString:@"dump"]||[_selectedOption isEqualToString:@"binary-dump"]))
        {
            return -1;
        }
        
        ApplicationsManager *_appsManager = [[ApplicationsManager alloc] init];
        
        NSDictionary *_installedApps = [_appsManager _allCachedApplications];
        NSArray* _installedArray = _installedApps.allValues;
        
        NSArray* selections = [_selectedBundleID componentsSeparatedByString:@" "];
        
        for (NSString* selection in selections)
        {
            int key;
            
            Application *_selectedApp;
            
            if (!(key = [selection intValue]))
            {
                [[ClutchPrint sharedInstance] printDeveloper:@"using bundle identifier"];
                if (_installedApps[selection] == nil)
                {
                    gbprintln(@"Couldn't find installed app with bundle identifier: %@",_selectedBundleID);
                    exit(1);
                }
                else
                {
                    _selectedApp = _installedApps[selection];
                }
            }
            else
            {
                [[ClutchPrint sharedInstance] printDeveloper:@"using number"];
                key = key - 1;
                
                if (key > [_installedArray count])
                {
                    gbprintln(@"Couldn't find app with corresponding number!?!");
                    exit(1);
                }
                _selectedApp = [_installedArray objectAtIndex:key];
                
            }
            
            
            if (!_selectedApp)
            {
                [[ClutchPrint sharedInstance] print:@"Couldn't find installed app"];
                exit(1);
            }
            
            [[ClutchPrint sharedInstance] printVerbose:@"Now dumping %@", _selectedApp.bundleIdentifier];

#ifndef DEBUG
            if (_selectedApp.hasAppleWatchApp)
            {
                [[ClutchPrint sharedInstance] print:@"%@ contains watchOS 2 compatible application. It's not possible to dump watchOS 2 apps with Clutch %@ at this moment.",_selectedApp.bundleIdentifier,CLUTCH_VERSION];
            }
#endif
            
            gettimeofday(&start, NULL);
            [_selectedApp dumpToDirectoryURL:nil onlyBinaries:[_selectedOption isEqualToString:@"binary-dump"]];
            
            CFRunLoopRun();
            
            [[ClutchPrint sharedInstance] printDeveloper:@"you shouldnt be there pal. exiting with -1 code"];
            return -1;
        }
    }
	return 0;
}

void sha1(uint8_t *hash, uint8_t *data, size_t size);

void sha1(uint8_t *hash, uint8_t *data, size_t size)
{
    SHA1Context context;
    SHA1Reset(&context);
    SHA1Input(&context, data, (unsigned)size);
    SHA1Result(&context, hash);
}

void exit_with_errno (int err, const char *prefix);
void exit_with_errno (int err, const char *prefix)
{
    if (err)
    {
        fprintf (stderr,
                 "%s%s",
                 prefix ? prefix : "",
                 strerror(err));
        exit (err);
    }
}

void _kill(pid_t pid);
void _kill(pid_t pid)
{
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        int result;
        waitpid(pid, &result, 0);
        waitpid(pid, &result, 0);
        kill(pid, SIGKILL); //just in case;
    });
    
    kill(pid, SIGCONT);
    kill(pid, SIGKILL);
}


