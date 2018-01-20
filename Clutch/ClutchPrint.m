//
//  ClutchPrint.m
//  Clutch
//
//  Created by dev on 15/02/2016.
//
//

#import "ClutchPrint.h"

@interface ClutchPrint ()
{
    ClutchPrinterColorLevel colorLevel;
    ClutchPrinterVerboseLevel verboseLevel;
}

@end

@implementation ClutchPrint

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static id shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [self new];
    });
    
    return shared;
}

- (void)setVerboseLevel:(ClutchPrinterVerboseLevel)verboseLev
{
    verboseLevel = verboseLev;
}

- (void)setColorLevel:(ClutchPrinterColorLevel)colorLev
{
    colorLevel = colorLev;
}

- (instancetype)initWithColorLevel:(ClutchPrinterColorLevel)colorLev verboseLevel:(ClutchPrinterVerboseLevel)verboseLev
{
    if (self = [super init])
    {
        verboseLevel = verboseLev;
        colorLevel = colorLev;
    }
    
    return self;
}

- (void)print:(NSString *)format, ...
{
    if (format != nil)
    {
        va_list args;
        va_start(args, format);
        NSString *formatString = [[NSString alloc] initWithFormat:format arguments:args];
        NSString *printString = [NSString stringWithFormat:@"%@\n", formatString];
        printf("%s", printString.UTF8String);
        va_end(args);
    }
}

- (void)printDeveloper:(NSString *)format, ...
{
    //#ifdef DEBUG
    if (verboseLevel == ClutchPrinterVerboseLevelDeveloper || verboseLevel == ClutchPrinterVerboseLevelFull)
    {
        if (format != nil)
        {
            NSString *stackSymobolsString = [NSThread callStackSymbols][1];
            NSMutableArray *stackSymbols = [NSMutableArray arrayWithArray:[stackSymobolsString  componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" -[]+?.,"]]];
            [stackSymbols removeObject:@""];

            va_list args;
            va_start(args, format);
            NSString *formatString = [[NSString alloc] initWithFormat:format arguments:args];
            NSString *printString = [NSString stringWithFormat:@"%@ | %@\n", stackSymbols[3], formatString];
            printf("%s", printString.UTF8String);
            va_end(args);
        }
    }
    //#endif
}

- (void)printError:(NSString *)format, ...
{
    if (format != nil)
    {
        va_list args;
        va_start(args, format);
        
        NSString *formatString = [[NSString alloc] initWithFormat:format arguments:args];
        NSString *printString = [NSString stringWithFormat:@"Error: %@\n", formatString];
        
        [self printColor:ClutchPrinterColorRed format:@"%@", printString];
        va_end(args);
    }
}

- (void)printColor:(ClutchPrinterColor)color format:(NSString *)format, ...
{
    if (format != nil)
    {
        va_list args;
        va_start(args, format);
        NSString *formatString = [[NSString alloc] initWithFormat:format arguments:args];
        NSString *printString;
        if (colorLevel == ClutchPrinterColorLevelNone)
        {
            printString = [NSString stringWithFormat:@"%@\n", formatString];
        }
        else if (colorLevel == ClutchPrinterColorLevelFull)
        {
            NSString *colorString;
            switch (color)
            {
                case ClutchPrinterColorPink:
                    colorString = @"\033[1;35m";
                    break;
                case ClutchPrinterColorRed:
                    colorString = @"\033[1;31m";
                    break;
                case ClutchPrinterColorPurple:
                    colorString = @"\033[0;34m";
                    break;
                default:
                    colorString = @"";
                    break;
            }
            
            printString = [NSString stringWithFormat:@"%@%@\033[0m\n", colorString, formatString];
        }
        
        
        printf("%s", printString.UTF8String);
        va_end(args);
    }
}

- (void)printVerbose:(NSString *)format, ...
{
    if (verboseLevel == ClutchPrinterVerboseLevelDeveloper || verboseLevel == ClutchPrinterVerboseLevelFull)
    {
        if (format != nil)
        {
            va_list args;
            va_start(args, format);
            
            NSString *formatString =[[NSString alloc] initWithFormat:format arguments:args];
            NSString *printString = [NSString stringWithFormat:@"%@\n", formatString];
            
            printf("%s", printString.UTF8String);
            va_end(args);
        }
    }
}


@end
