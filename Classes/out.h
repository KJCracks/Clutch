#import <sys/ioctl.h>
#include <sys/types.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#import "Configuration.h"

// print something verbose
//#define VERBOSE(x) if ([[ClutchConfiguration getValue:@"VerboseLogging"] isEqualToString:@"YES"]) { progress_event(x); };
#define VERBOSE(x) { progress_event(x); };
// output some data
#define NOTIFY(x) progress_message(x);
// update percentage of currently running task
#define PERCENT(x) progress_percent(x);

#define DEBUG_MODE 1

#ifdef DEBUG_MODE
#   define FILE_NAME (strrchr(__FILE__, '/') ? strrchr(__FILE__, '/') + 1 : __FILE__) // shortened path of __FILE__ is there is one
#   define DEBUG(M, ...) fprintf(stderr, "\033[0;32mDEBUG\033[0m | %s:%d | " M "\n", FILE_NAME, __LINE__, ##__VA_ARGS__); // print C objects
#   define NSLog(M, ...) fprintf(stderr, "\033[0;32mDEBUG\033[0m | %s:%d | %s\n", FILE_NAME, __LINE__, [[NSString stringWithFormat:M, ##__VA_ARGS__] UTF8String]);
#else
#   define DEBUG(M, ...)
#   define NSLog(...)
#endif

int determine_screen_width (void);
void progress_percent(int percent);
void progress_message(char *msg);
void progress_event(char *text);

void print_bar(void);
void stop_bar(void);
void pause_bar(void);