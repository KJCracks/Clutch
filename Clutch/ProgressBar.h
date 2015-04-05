#import <sys/ioctl.h>
#include <sys/types.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

// update percentage of currently running task
#define PERCENT(x) progress_percent(x);

int determine_screen_width (void);
void progress_percent(int percent);
void progress_message(char *msg);
void progress_event(char *text);

void print_bar(void);
void stop_bar(void);
void pause_bar(void);