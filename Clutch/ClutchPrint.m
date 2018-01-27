//
//  ClutchPrint.m
//  Clutch
//
//  Created by dev on 15/02/2016.
//
//

#import "ClutchPrint.h"

NSUInteger KJPrintCurrentLogLevel = KJPrintLogLevelNormal;

static NSInteger KJPrintv(NSString *format, va_list ap) {
    if (![format hasSuffix:@"\n"]) {
        format = [format stringByAppendingString:@"\n"];
    }
    NSString *s = [[NSString alloc] initWithFormat:format arguments:ap];
    return printf("%s", s.UTF8String);
}

NSInteger KJPrint(NSString *format, ...) {
    va_list ap;
    va_start(ap, format);
    NSInteger ret = KJPrintv(format, ap);
    va_end(ap);
    return ret;
}

NSInteger KJPrintVerbose(NSString *format, ...) {
    if (KJPrintCurrentLogLevel < KJPrintLogLevelVerbose) {
        return 0;
    }
    va_list ap;
    va_start(ap, format);
    NSInteger ret = KJPrintv(format, ap);
    va_end(ap);
    return ret;
}

#if defined(DEBUG) && DEBUG
NSInteger KJDebug(NSString *format, ...) {
    if (KJPrintCurrentLogLevel < KJPrintLogLevelDebug) {
        return 0;
    }
    va_list ap;
    va_start(ap, format);
    NSInteger ret = KJPrintv(format, ap);
    va_end(ap);
    return ret;
}
#endif
