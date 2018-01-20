//
//  ClutchPrint.h
//  Clutch
//
//  Created by dev on 15/02/2016.
//
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ClutchPrinterVerboseLevel) {
    ClutchPrinterVerboseLevelNone = 0,
    ClutchPrinterVerboseLevelUser = 1,
    ClutchPrinterVerboseLevelDeveloper = 2,
    ClutchPrinterVerboseLevelFull = 3
};

typedef NS_ENUM(NSInteger, ClutchPrinterColorLevel) {
    ClutchPrinterColorLevelNone = 0,
    ClutchPrinterColorLevelFormatOnly = 1,
    ClutchPrinterColorLevelFull = 2,
};

typedef NS_ENUM(NSInteger, ClutchPrinterColor) {
    ClutchPrinterColorNone = 0,
    ClutchPrinterColorRed = 1,
    ClutchPrinterColorPurple = 2,
    ClutchPrinterColorPink = 3
};

/*#define ClutchPrint(f, ...) [[ClutchPrint sharedInstance] printWithFormat:[NSString stringWithFormat:(f),
##__VA_ARGS__]] #define ClutchPrintDeveloper(f, ...) [[ClutchPrint sharedInstance]
printDeveloperWithFileArguments:@[[[NSString stringWithUTF8String:__FILE__] lastPathComponent], [NSNumber
numberWithInt:__LINE__], [NSString stringWithUTF8String:__PRETTY_FUNCTION__]] format:[NSString stringWithFormat:(f),
#__VA_ARGS__]] #define ClutchPrintVerbose(f, ...) [[ClutchPrint sharedInstance] printVerboseWithFormat:[NSString
stringWithFormat:(f), ##__VA_ARGS__]] #define ClutchPrintError(f, ...) [[ClutchPrint sharedInstance]
printError:[NSString stringWithFormat:(f), ##__VA_ARGS__]] #define ClutchPrintColor(color, f, ...)[[ClutchPrint
sharedInstance] printColoredStringWithColor:color message:[NSString stringWithFormat:(f), ##__VA_ARGS__]]
*/

@interface ClutchPrint : NSObject
- (instancetype)initWithColorLevel:(ClutchPrinterColorLevel)colorLevel
                      verboseLevel:(ClutchPrinterVerboseLevel)verboseLevel;

+ (instancetype)sharedInstance;

- (void)print:(NSString *)format, ...;
- (void)printDeveloper:(NSString *)format, ...;
- (void)printDeveloper:(NSString *)format arguments:(va_list)args;
- (void)printVerbose:(NSString *)format, ...;
- (void)printError:(NSString *)format, ...;
- (void)printColor:(ClutchPrinterColor)color format:(NSString *)format, ...;

- (void)setColorLevel:(ClutchPrinterColorLevel)colorLev;
- (void)setVerboseLevel:(ClutchPrinterVerboseLevel)verboseLev;

@end

NS_INLINE void ClutchPrintDeveloper(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    [[ClutchPrint sharedInstance] printDeveloper:format arguments:args];
    va_end(args);
}
