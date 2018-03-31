//
//  ClutchCommands.m
//  Clutch
//
//  Created by dev on 10/01/2017.
//
//

#import "ClutchCommands.h"
#import "ClutchPrint.h"

@interface ClutchCommand ()

- (instancetype)initWithCommandOption:(ClutchCommandOption)commandOption
                          shortOption:(NSString *)shortOption
                           longOption:(NSString *)longOption
                   commandDescription:(NSString *)commandDescription
                                 flag:(ClutchCommandFlag)flag;
+ (instancetype)commandWithCommandOption:(ClutchCommandOption)commandOption
                             shortOption:(NSString *)shortOption
                              longOption:(NSString *)longOption
                      commandDescription:(NSString *)commandDescription
                                    flag:(ClutchCommandFlag)flag;

@end

@implementation ClutchCommand

- (instancetype)initWithCommandOption:(ClutchCommandOption)commandOption
                          shortOption:(NSString *)shortOption
                           longOption:(NSString *)longOption
                   commandDescription:(NSString *)commandDescription
                                 flag:(ClutchCommandFlag)flag {
    if ((self = [super self])) {
        _option = commandOption;
        _shortOption = shortOption;
        _longOption = longOption;
        _commandDescription = commandDescription;
        _flag = flag;
    }

    return self;
}

+ (instancetype)commandWithCommandOption:(ClutchCommandOption)commandOption
                             shortOption:(NSString *)shortOption
                              longOption:(NSString *)longOption
                      commandDescription:(NSString *)commandDescription
                                    flag:(ClutchCommandFlag)flag {
    return [[self alloc] initWithCommandOption:commandOption
                                   shortOption:shortOption
                                    longOption:longOption
                            commandDescription:commandDescription
                                          flag:flag];
}

@end

@implementation ClutchCommands

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments {
    if ((self = [super self])) {
        _allCommands = [self buildCommands];
        _commands = [self parseCommandWithArguments:arguments];
        _helpString = [self buildHelpString];
    }

    return self;
}

- (NSArray<ClutchCommand *> *)parseCommandWithArguments:(NSArray<NSString *> *)arguments {
    NSMutableArray<ClutchCommand *> *returnCommands = [NSMutableArray new];
    NSMutableArray<NSString *> *returnValues = [NSMutableArray new];
    BOOL commandFound = NO;

    for (NSString *argument in arguments) {
        if ([argument isEqualToString:arguments[0]]) {
            continue;
        } else if ([argument isEqualToString:@"--no-color"]) {
            // Optionals
            [returnCommands insertObject:self.allCommands[8] atIndex:0];
        } else if ([argument isEqualToString:@"--verbose"]) {
            [returnCommands insertObject:self.allCommands[9] atIndex:0];
        } else if ([argument isEqualToString:@"--debug"]) {
            [returnCommands insertObject:self.allCommands[10] atIndex:0];
        } else if ([argument hasPrefix:@"-"]) {
            // is a flag
            for (ClutchCommand *command in self.allCommands) {
                if ([argument isEqualToString:command.shortOption] || [argument isEqualToString:command.longOption]) {
                    if (!commandFound) {
                        commandFound = YES;
                        [returnCommands addObject:command];
                        break;
                    } else {
                        KJPrint(@"Ignoring incorrectly chained command and values: %@.", argument);
                        // ignore 2nd command in chained commands like -b foo -d bar
                    }
                }
            }
        } else {
            // is a value
            [returnValues addObject:argument];
        }
    }

    if (returnCommands.count < 1) {
        return @[ self.allCommands[0] ];
    }

    _values = returnValues;

    return returnCommands;
}

- (NSArray<ClutchCommand *> *)buildCommands {
    ClutchCommand *none =
        [ClutchCommand commandWithCommandOption:ClutchCommandOptionNone
                                    shortOption:nil
                                     longOption:nil
                             commandDescription:@"None command"
                                           flag:ClutchCommandFlagInvisible | ClutchCommandFlagNoArguments];
    ClutchCommand *framework =
        [ClutchCommand commandWithCommandOption:ClutchCommandOptionFrameworkDump
                                    shortOption:@"-f"
                                     longOption:@"--fmwk-dump"
                             commandDescription:@"Only dump binary files from specified bundleID"
                                           flag:ClutchCommandFlagArgumentRequired | ClutchCommandFlagInvisible];
    ClutchCommand *binary = [ClutchCommand commandWithCommandOption:ClutchCommandOptionBinaryDump
                                                        shortOption:@"-b"
                                                         longOption:@"--binary-dump"
                                                 commandDescription:@"Only dump binary files from specified bundleID"
                                                               flag:ClutchCommandFlagArgumentRequired];
    ClutchCommand *dump = [ClutchCommand commandWithCommandOption:ClutchCommandOptionDump
                                                      shortOption:@"-d"
                                                       longOption:@"--dump"
                                               commandDescription:@"Dump specified bundleID into .ipa file"
                                                             flag:ClutchCommandFlagArgumentRequired];
    ClutchCommand *printInstalled = [ClutchCommand commandWithCommandOption:ClutchCommandOptionPrintInstalled
                                                                shortOption:@"-i"
                                                                 longOption:@"--print-installed"
                                                         commandDescription:@"Prints installed applications"
                                                                       flag:ClutchCommandFlagNoArguments];
    ClutchCommand *clean = [ClutchCommand commandWithCommandOption:ClutchCommandOptionClean
                                                       shortOption:nil
                                                        longOption:@"--clean"
                                                commandDescription:@"Clean /var/tmp/clutch directory"
                                                              flag:ClutchCommandFlagNoArguments];
    ClutchCommand *version = [ClutchCommand commandWithCommandOption:ClutchCommandOptionVersion
                                                         shortOption:nil
                                                          longOption:@"--version"
                                                  commandDescription:@"Display version and exit"
                                                                flag:ClutchCommandFlagNoArguments];
    ClutchCommand *help = [ClutchCommand commandWithCommandOption:ClutchCommandOptionHelp
                                                      shortOption:@"-?"
                                                       longOption:@"--help"
                                               commandDescription:@"Displays this help and exit"
                                                             flag:ClutchCommandFlagNoArguments];
    ClutchCommand *noColor = [ClutchCommand commandWithCommandOption:ClutchCommandOptionNoColor
                                                         shortOption:@"-n"
                                                          longOption:@"--no-color"
                                                  commandDescription:@"Prints with colors disabled"
                                                                flag:ClutchCommandFlagOptional];
    ClutchCommand *verbose = [ClutchCommand commandWithCommandOption:ClutchCommandOptionVerbose
                                                         shortOption:@"-v"
                                                          longOption:@"--verbose"
                                                  commandDescription:@"Print verbose messages"
                                                                flag:ClutchCommandFlagOptional];
    ClutchCommand *debug =
        [ClutchCommand commandWithCommandOption:ClutchCommandOptionDebug
                                    shortOption:nil
                                     longOption:@"--debug"
                             commandDescription:@"Enable debug logging. Only available with a debug build."
                                           flag:ClutchCommandFlagNoArguments | ClutchCommandFlagInvisible];

    return @[ none, framework, binary, dump, printInstalled, clean, version, help, noColor, verbose, debug ];
}

- (ClutchCommand *)parseCommandString:(NSString *)commandString {
    for (ClutchCommand *command in self.commands) {
        if ([commandString isEqualToString:command.shortOption] || [commandString isEqualToString:command.longOption]) {
            return command;
        }
    }

    return self.commands[0]; // return ClutchCommand None
}

- (NSString *)buildHelpString {
    NSMutableString *helpString =
        [NSMutableString stringWithFormat:@"Usage: %@ [OPTIONS]\n", NSProcessInfo.processInfo.processName];

    for (ClutchCommand *command in self.allCommands) {
        BOOL isInvisible = command.flag & ClutchCommandFlagInvisible;

        if (!isInvisible) {
            [helpString appendFormat:@"%-2s %-30s%@\n",
                                     command.shortOption.UTF8String ? command.shortOption.UTF8String : " ",
                                     command.longOption.UTF8String,
                                     command.commandDescription];
        }
    }

    return helpString;
}

@end
