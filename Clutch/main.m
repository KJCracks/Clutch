//
//  main.m
//  Clutch
//
//  Created by Anton Titkov on 09.02.15.
//  Copyright (c) 2015 AppAddict. All rights reserved.
//

#import "ClutchCommands.h"
#import "ClutchPrint.h"
#import "FrameworkLoader.h"
#import "KJApplicationManager.h"
#import "NSTask.h"
#import "sha1.h"
#import <Foundation/Foundation.h>
#import <sys/time.h>
#include <unistd.h>

struct timeval gStart;

NSInteger diff_ms(struct timeval t1, struct timeval t2);
NSInteger diff_ms(struct timeval t1, struct timeval t2) {
    return (((t1.tv_sec - t2.tv_sec) * 1000000) + (t1.tv_usec - t2.tv_usec)) / 1000;
}

void listApps(void);
void listApps() {
    KJApplicationManager *_manager = [[KJApplicationManager alloc] init];

    NSArray *installedApps = _manager.installedApps.allValues;
    KJPrint(@"Installed apps:");

    NSUInteger count;
    NSString *space;
    for (Application *_app in installedApps) {
        count = [installedApps indexOfObject:_app] + 1;
        if (count < 10) {
            space = @"  ";
        } else if (count < 100) {
            space = @" ";
        }

        KJPrint(@"%d: %@%@ <%@>", count, space, _app.displayName, _app.bundleIdentifier);
    }
}

int main(int argc, const char *argv[]) {
    CLUTCH_UNUSED(argc);
    CLUTCH_UNUSED(argv);

    @autoreleasepool {
        if (getuid() != 0) { // Clutch needs to be root user to run
            KJPrint(@"Clutch needs to be run as the root user, please change user and rerun.");
            return 0;
        }

        if (SYSTEM_VERSION_LESS_THAN(NSFoundationVersionNumber_iOS_8_0)) {
            KJPrint(@"You need iOS 8.0+ to use Clutch %@", CLUTCH_VERSION);
            return 0;
        }

        BOOL dumpedFramework = NO;
        BOOL successfullyDumpedFramework = NO;
        NSString *_selectedOption = @"";
        NSString *_selectedBundleID;

        NSArray<NSString *> *arguments = [NSProcessInfo processInfo].arguments;

        ClutchCommands *commands = [[ClutchCommands alloc] initWithArguments:arguments];

        NSArray *values;

        if (commands.commands) {
            for (ClutchCommand *command in commands.commands) {
                NSLog(@"command: %@", command.commandDescription);
                // Switch flags
                switch (command.flag) {
                    case ClutchCommandFlagArgumentRequired: {
                        values = commands.values;
                    }
                    default:
                        break;
                }

                // Switch optionals
                switch (command.option) {
                    case ClutchCommandOptionVerbose:
                        KJPrintCurrentLogLevel = KJPrintLogLevelVerbose;
                        break;
                    case ClutchCommandOptionDebug:
                        KJPrintCurrentLogLevel = KJPrintLogLevelDebug;
                    default:
                        break;
                }

                switch (command.option) {
                    case ClutchCommandOptionNone: {
                        KJPrint(@"%@", commands.helpString);
                        break;
                    }
                    case ClutchCommandOptionFrameworkDump: {
                        NSArray<NSString *> *args = [NSProcessInfo processInfo].arguments;

                        if (([args[1] isEqualToString:@"--fmwk-dump"] || [args[1] isEqualToString:@"-f"]) &&
                            (args.count == 13)) {
                            FrameworkLoader *fmwk = [FrameworkLoader new];

                            fmwk.binPath = args[2];
                            fmwk.dumpPath = args[3];
                            fmwk.pages = (uint32_t)[args[4] intValue];
                            fmwk.ncmds = (uint32_t)[args[5] intValue];
                            fmwk.offset = (uint32_t)[args[6] intValue];
                            fmwk.bID = args[7];
                            fmwk.hashOffset = (uint32_t)[args[8] intValue];
                            fmwk.codesign_begin = (uint32_t)[args[9] intValue];
                            fmwk.cryptsize = (uint32_t)[args[10] intValue];
                            fmwk.cryptoff = (uint32_t)[args[11] intValue];
                            fmwk.cryptlc_offset = (uint32_t)[args[12] intValue];
                            fmwk.dumpSize = fmwk.cryptoff + fmwk.cryptsize;

                            BOOL result = successfullyDumpedFramework = [fmwk dumpBinary];

                            if (result) {
                                KJPrint(@"Successfully dumped framework %@!", fmwk.binPath.lastPathComponent);

                                return 0;
                            } else {
                                KJPrint(@"Failed to dump framework %@ :(", fmwk.binPath.lastPathComponent);
                                return 1;
                            }

                        } else if (args.count != 13) {
                            KJPrint(@"Incorrect amount of arguments - see source if you're using this.");
                        }

                        break;
                    }
                    case ClutchCommandOptionBinaryDump:
                    case ClutchCommandOptionDump: {
                        NSDictionary *_installedApps = [[[KJApplicationManager alloc] init] cachedApplications];
                        NSArray *_installedArray = _installedApps.allValues;

                        for (NSString *selection in values) {
                            NSUInteger key;
                            Application *_selectedApp;

                            if (!(key = (NSUInteger)selection.integerValue)) {
                                KJDebug(@"using bundle identifier");
                                if (_installedApps[selection] == nil) {
                                    KJPrint(@"Couldn't find installed app with bundle identifier: %@",
                                            _selectedBundleID);
                                    return 1;
                                } else {
                                    _selectedApp = _installedApps[selection];
                                }
                            } else {
                                KJDebug(@"using number");
                                key = key - 1;

                                if (key > _installedArray.count) {
                                    KJPrint(@"Couldn't find app with corresponding number!?!");
                                    return 1;
                                }
                                _selectedApp = _installedArray[key];
                            }

                            if (!_selectedApp) {
                                KJPrint(@"Couldn't find installed app");
                                return 1;
                            }

                            KJPrintVerbose(@"Now dumping %@", _selectedApp.bundleIdentifier);

                            if (_selectedApp.hasAppleWatchApp) {
                                KJPrint(@"%@ contains watchOS 2 compatible application. It's not possible to dump "
                                        @"watchOS 2 apps with Clutch %@ at this moment.",
                                        _selectedApp.bundleIdentifier,
                                        CLUTCH_VERSION);
                            }

                            gettimeofday(&gStart, NULL);
                            if (![_selectedApp dumpToDirectoryURL:nil
                                                     onlyBinaries:[_selectedOption isEqualToString:@"binary-dump"]]) {
                                return 1;
                            }
                        }
                        break;
                    }
                    case ClutchCommandOptionPrintInstalled: {
                        listApps();
                        break;
                    }
                    case ClutchCommandOptionClean: {
                        [[NSFileManager defaultManager] removeItemAtPath:@"/var/tmp/clutch" error:nil];
                        [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/tmp/clutch"
                                                  withIntermediateDirectories:YES
                                                                   attributes:nil
                                                                        error:nil];
                        break;
                    }
                    case ClutchCommandOptionVersion: {
                        KJPrint(CLUTCH_VERSION);
                        break;
                    }
                    case ClutchCommandOptionHelp: {
                        KJPrint(@"%@", commands.helpString);
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

void sha1(uint8_t *hash, uint8_t *data, size_t size) {
    SHA1Context context;
    SHA1Reset(&context);
    SHA1Input(&context, data, (unsigned)size);
    SHA1Result(&context, hash);
}

void exit_with_errno(int err, const char *prefix);
void exit_with_errno(int err, const char *prefix) {
    if (err) {
        fprintf(stderr, "%s%s", prefix ? prefix : "", strerror(err));
        fclose(stdout);
        fclose(stderr);
        exit(err);
    }
}

void _kill(pid_t pid);
void _kill(pid_t pid) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        int result;
        waitpid(pid, &result, 0);
        waitpid(pid, &result, 0);
        kill(pid, SIGKILL); // just in case;
    });

    kill(pid, SIGCONT);
    kill(pid, SIGKILL);
}
