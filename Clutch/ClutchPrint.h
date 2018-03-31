//
//  ClutchPrint.h
//  Clutch
//
//  Created by dev on 15/02/2016.
//
//

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXTERN NSUInteger KJPrintCurrentLogLevel;
typedef NS_ENUM(NSUInteger, KJPrintLogLevel) {
    KJPrintLogLevelNormal = 0,
    KJPrintLogLevelVerbose = 1,
    KJPrintLogLevelDebug = 2,
};

NSInteger KJPrint(NSString *format, ...);
NSInteger KJPrintVerbose(NSString *format, ...);
#if defined(DEBUG) && DEBUG
NSInteger KJDebug(NSString *format, ...);
#else
#define KJDebug(x...)
#endif

NS_ASSUME_NONNULL_END
