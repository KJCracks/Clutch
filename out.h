//
//  out.h
//  Clutch
//
//  Created by Thomas Hedderwick on 24/11/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#import <sys/ioctl.h>
#include <sys/types.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <stdbool.h>

// print something verbise
#define VERBOSE(x) progress_verbose(x);

// output some data
#define DEBUG(x) progress_debug(x);

// print something important
#define NOTIFY(x) progress_message(x);

// update percentage of currently running task
#define PERCENT(x) progress_percent(x);

// print an error
#define ERROR(x) progress_error(x);

// print a
#define LOG(x, ...) progress_log(x, __VA_ARGS__)

// NSLog objects (this is basically developer only/debug only)
#define NSLog(x, ...) fprintf(stderr, "%s\n", [[NSString stringWithFormat:x, ##__VA_ARGS__] UTF8String]);

void set_debug(bool should_debug);
void set_colors(bool should_color);

int determine_screen_width (void);

void progress_log(char *msg, ...);
void progress_verbose(char *msg);
void progress_debug(char *msg);
void progress_percent(int percent);
void progress_error(char *msg);
void progress_message(char *msg);

void print_bar(void);
void stop_bar(void);
void pause_bar(void);