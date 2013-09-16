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

int determine_screen_width (void);
void progress_percent(int percent);
void progress_message(char *msg);
void progress_event(char *text);

void print_bar(void);
void stop_bar(void);
void pause_bar(void);