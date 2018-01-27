//
//  ClutchCommands.h
//  Clutch
//
//  Created by dev on 10/01/2017.
//
//

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

@property (nonatomic, assign, readonly) ClutchCommandOption option;
@property (nonatomic, retain, readonly) NSString *shortOption;
@property (nonatomic, retain, readonly) NSString *longOption;
@property (nonatomic, retain, readonly) NSString *commandDescription;
@property (nonatomic, assign, readonly) ClutchCommandFlag flag;

@end

@interface ClutchCommands : NSObject

@property (nonatomic, retain, readonly) NSArray<ClutchCommand *> *allCommands;
@property (nonatomic, retain, readonly) NSArray<ClutchCommand *> *commands;
@property (nonatomic, retain, readonly) NSString *helpString;
@property (nonatomic, retain, readonly) NSArray<NSString *> *values;

- (instancetype)initWithArguments:(NSArray<NSString *> *)arguments;

@end
