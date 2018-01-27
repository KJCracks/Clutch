//
//  ClutchCommands.h
//  Clutch
//
//  Created by dev on 10/01/2017.
//
//

#import <Foundation/Foundation.h>

typedef NS_OPTIONS(NSInteger, ClutchCommandFlag) {
    ClutchCommandFlagNone = 0,
    ClutchCommandFlagInvisible = 1 << 0,        // don't print to help
    ClutchCommandFlagArgumentRequired = 1 << 1, // requires args
    ClutchCommandFlagNoArguments = 1 << 2,      // will not take args
    ClutchCommandFlagOptional = 1 << 3,         // can be optionally added to any other command (i.e. --verbose)
};

typedef NS_ENUM(NSUInteger, ClutchCommandOption) {
    ClutchCommandOptionNone,
    ClutchCommandOptionFrameworkDump,
    ClutchCommandOptionBinaryDump,
    ClutchCommandOptionDump,
    ClutchCommandOptionPrintInstalled,
    ClutchCommandOptionClean,
    ClutchCommandOptionVersion,
    ClutchCommandOptionHelp,
    ClutchCommandOptionNoColor,
    ClutchCommandOptionVerbose,
    ClutchCommandOptionDebug,
};

@interface ClutchCommand : NSObject

@property (nonatomic, assign) ClutchCommandOption option;
@property (nonatomic, retain) NSString *shortOption;
@property (nonatomic, retain) NSString *longOption;
@property (nonatomic, retain) NSString *commandDescription;
@property (nonatomic, assign) ClutchCommandFlag flag;

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

@interface ClutchCommands : NSObject

@property (nonatomic, retain) NSArray *allCommands;
@property (nonatomic, retain) NSArray *commands;
@property (nonatomic, retain) NSString *helpString;
@property (nonatomic, retain) NSArray *values;

- (instancetype)initWithArguments:(NSArray *)arguments;

@end
