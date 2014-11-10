#import <sys/ioctl.h>
#include <sys/types.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

// print something verbose
#define VERBOSE(x) { progress_event(x); };

// output some data
#define NOTIFY(x) progress_message(x);

// update percentage of currently running task
#define PERCENT(x) progress_percent(x);


#define NSPrint(M, ...) fprintf(stderr, "%s \n", [[NSString stringWithFormat:M, ##__VA_ARGS__] UTF8String]);

#define CLUTCH_DEV 1

#if CLUTCH_DEV == 1
#   define FILE_NAME (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__) // shortened path of __FILE__ is there is one
#
#   define NSLog(M, ...) fprintf(stderr, "\033[0;32mDEBUG\033[0m | %s:%d | %s\n", FILE_NAME, __LINE__, [[NSString stringWithFormat:M, ##__VA_ARGS__] UTF8String]);
#   define DEBUG(M, ...) fprintf(stderr, "\033[0;32mDEBUG\033[0m | %s:%d | %s\n", FILE_NAME, __LINE__, [[NSString stringWithFormat:M, ##__VA_ARGS__] UTF8String]);
#   define DEBUG(M, ...) fprintf(stderr, "\033[0;32mDEBUG\033[0m | %s:%d | %s\n", FILE_NAME, __LINE__, [[NSString stringWithFormat:M, ##__VA_ARGS__] UTF8String]);
#   define ERROR(M, ...) fprintf(stderr, "\033[0;32mERROR\033[0m | %s \n", [[NSString stringWithFormat:M, ##__VA_ARGS__] UTF8String]);
#else
//#   define FILE_NAME (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__) // shortened path of __FILE__ is there is one
//#
#   define NSLog(M, ...)
#   define DEBUG(M, ...)
#   define ERROR(M, ...)
#endif

int determine_screen_width (void);
void progress_percent(int percent);
void progress_message(char *msg);
void progress_event(char *text);

void print_bar(void);
void stop_bar(void);
void pause_bar(void);
