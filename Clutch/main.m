//
//  main.m
//  Clutch
//
//  Created by Anton Titkov on 09.02.15.
//  Copyright (c) 2015 AppAddict. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ApplicationsManager.h"
#import "sha1.h"
#import "FrameworkLoader.h"
#import <sys/time.h>
#import "ClutchPrint.h"
#import "NSTask.h"
#include <unistd.h>
#import "ClutchCommands.h"

struct timeval gStart;

int diff_ms(struct timeval t1, struct timeval t2)
{
    return (int)((((t1.tv_sec - t2.tv_sec) * 1000000) +
                  (t1.tv_usec - t2.tv_usec)) / 1000);
}

void listApps(void);
void listApps() {
    ApplicationsManager *_manager = [[ApplicationsManager alloc] init];

    NSArray *installedApps = [_manager installedApps].allValues;
    [[ClutchPrint sharedInstance] print:@"Installed apps:"];

    NSUInteger count;
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
}

int main (int argc, const char * argv[])
{
    CLUTCH_UNUSED(argc);
    CLUTCH_UNUSED(argv);
    
    @autoreleasepool
    {
        if (getuid() != 0) { // Clutch needs to be root user to run
            [[ClutchPrint sharedInstance] print:@"Clutch needs to be run as the root user, please change user and rerun."];

            return 0;
        }

        if (SYSTEM_VERSION_LESS_THAN(NSFoundationVersionNumber_iOS_8_0))
        {
            [[ClutchPrint sharedInstance] print:@"You need iOS 8.0+ to use Clutch %@", CLUTCH_VERSION];

            return 0;
        }
        
        [[ClutchPrint sharedInstance] setColorLevel:ClutchPrinterColorLevelFull];
        [[ClutchPrint sharedInstance] setVerboseLevel:ClutchPrinterVerboseLevelNone];
        
        BOOL dumpedFramework = NO;
        BOOL successfullyDumpedFramework = NO;
        NSString *_selectedOption = @"";
        NSString *_selectedBundleID;
        
        NSArray *arguments = [[NSProcessInfo processInfo] arguments];

        ClutchCommands *commands = [[ClutchCommands alloc] initWithArguments:arguments];
                                    
        NSArray *values;
    
        if (commands.commands)
        {
            for (ClutchCommand *command in commands.commands)
            {
                NSLog(@"command: %@", command.commandDescription);
                // Switch flags
                switch (command.flag) {
                    case ClutchCommandFlagArgumentRequired:
                    {
                        values = commands.values;
                    }
                    default:
                        break;
                }
                
                // Switch optionals
                switch (command.option)
                {
                    case ClutchCommandOptionNoColor:
                        [[ClutchPrint sharedInstance] setColorLevel:ClutchPrinterColorLevelNone];
                        break;
                    case ClutchCommandOptionVerbose:
                        [[ClutchPrint sharedInstance] setVerboseLevel:ClutchPrinterVerboseLevelFull];
                        break;
                    default:
                        break;
                }
                
                switch (command.option) {
                    case ClutchCommandOptionNone:
                    {
                        [[ClutchPrint sharedInstance] print:@"%@", commands.helpString];
                        break;
                    }
                    case ClutchCommandOptionFrameworkDump:
                    {
                        NSArray *args = [NSProcessInfo processInfo].arguments;
                        
                        if (([args[1] isEqualToString:@"--fmwk-dump"] || [args[1] isEqualToString:@"-f"]) && (args.count == 13))
                        {
                            dumpedFramework = YES;
                            FrameworkLoader *fmwk = [FrameworkLoader new];
                            
                            fmwk.binPath = args[2];
                            fmwk.dumpPath = args[3];
                            fmwk.pages = [args[4] unsignedIntValue];
                            fmwk.ncmds = [args[5] unsignedIntValue];
                            fmwk.offset = [args[6] unsignedIntValue];
                            fmwk.bID = args[7];
                            fmwk.hashOffset = [args[8] unsignedIntValue];
                            fmwk.codesign_begin = [args[9] unsignedIntValue];
                            fmwk.cryptsize = [args[10] unsignedIntValue];
                            fmwk.cryptoff = [args[11] unsignedIntValue];
                            fmwk.cryptlc_offset = [args[12] unsignedIntValue];
                            fmwk.dumpSize = fmwk.cryptoff + fmwk.cryptsize;
                            
                            
                            BOOL result = successfullyDumpedFramework = [fmwk dumpBinary];
                            
                            if (result)
                            {
                                [[ClutchPrint sharedInstance] printColor:ClutchPrinterColorPurple format:@"Successfully dumped framework %@!", fmwk.binPath.lastPathComponent];
                                
                                return 1;
                            }
                            else {
                                [[ClutchPrint sharedInstance] printColor:ClutchPrinterColorPurple format:@"Failed to dump framework %@ :(", fmwk.binPath.lastPathComponent];
                                return 0;
                            }
                            
                        }
                        else if (args.count != 13)
                        {
                            [[ClutchPrint sharedInstance] printError:@"Incorrect amount of arguments - see source if you're using this."];
                        }

                        break;
                    }
                    case ClutchCommandOptionBinaryDump:
                    case ClutchCommandOptionDump:
                    {
                        NSDictionary *_installedApps = [[[ApplicationsManager alloc] init] _allCachedApplications];
                        NSArray* _installedArray = _installedApps.allValues;
                        
                        for (NSString* selection in values)
                        {
                            NSUInteger key;
                            Application *_selectedApp;
                            
                            if (!(key = (NSUInteger)selection.integerValue))
                            {
                                [[ClutchPrint sharedInstance] printDeveloper:@"using bundle identifier"];
                                if (_installedApps[selection] == nil)
                                {
                                    [[ClutchPrint sharedInstance] print:@"Couldn't find installed app with bundle identifier: %@",_selectedBundleID];
                                    return 1;
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
                                    [[ClutchPrint sharedInstance] print:@"Couldn't find app with corresponding number!?!"];
                                    return 1;
                                }
                                _selectedApp = [_installedArray objectAtIndex:key];
                                
                            }
                            
                            
                            if (!_selectedApp)
                            {
                                [[ClutchPrint sharedInstance] print:@"Couldn't find installed app"];
                                return 1;
                            }
                            
                            [[ClutchPrint sharedInstance] printVerbose:@"Now dumping %@", _selectedApp.bundleIdentifier];
                            
#ifndef DEBUG
                            if (_selectedApp.hasAppleWatchApp)
                            {
                                [[ClutchPrint sharedInstance] print:@"%@ contains watchOS 2 compatible application. It's not possible to dump watchOS 2 apps with Clutch %@ at this moment.",_selectedApp.bundleIdentifier,CLUTCH_VERSION];
                            }
#endif
                            
                            gettimeofday(&gStart, NULL);
                            if (![_selectedApp dumpToDirectoryURL:nil onlyBinaries:[_selectedOption isEqualToString:@"binary-dump"]]) {
                                return 1;
                            }
                        }
                        break;
                    }
                    case ClutchCommandOptionPrintInstalled:
                    {
                        listApps();
                        break;
                    }
                    case ClutchCommandOptionClean:
                    {
                        [[NSFileManager defaultManager]removeItemAtPath:@"/var/tmp/clutch" error:nil];
                        [[NSFileManager defaultManager]createDirectoryAtPath:@"/var/tmp/clutch" withIntermediateDirectories:YES attributes:nil error:nil];
                        break;
                    }
                    case ClutchCommandOptionVersion:
                    {
                        [[ClutchPrint sharedInstance] print:CLUTCH_VERSION];
                        break;
                    }
                    case ClutchCommandOptionHelp:
                    {
                        [[ClutchPrint sharedInstance] print:@"%@", commands.helpString];
                        break;
                    }
                    default:
                        // no command found.
                        break;
                }
            }
        }

        if (dumpedFramework) {
            fclose(stdin);
            fclose(stdout);
            fclose(stderr);

            if (successfullyDumpedFramework) {
                return 0;
            }
            return 1;
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
        fclose(stdout);
        fclose(stderr);
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
