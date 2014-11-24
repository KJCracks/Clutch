//
//  out.m
//  Clutch
//
//  Created by Thomas Hedderwick on 24/11/2014.
//  Copyright (c) 2014 Hackulous. All rights reserved.
//

#include <stdbool.h>
#include <stdio.h>
#include <stdarg.h>

#import "out.h"

#define ERROR_COLOR = "\033[0;31m"
#define DEBUG_COLOR = "\033[0;32m"
#define COLOR_END = "\033[J"

char error_color[] = "\033[0;31m";
char debug_color[] = "\033[0;32m";
char color_end[] = "\033[0m";

int bar_mode = 0;
int bar_percent = -1;
char bar_msg[300];
bool debug = false;
bool color = true;

/**
 *  Gets the screen width
 *
 *  @return winsize.ws_col
 */
int determine_screen_width (void)
{
    int file_descriptor;
    struct winsize window_size;
    
    file_descriptor = fileno(stderr);
    
    if (ioctl(file_descriptor, TIOCGWINSZ, &window_size) < 0)
    {
        return 0;
    }
    
    return window_size.ws_col;
}

/**
 *  Sets debug to @param
 *
 *  @param should_debug bool wanna debug?
 */
void set_debug(bool should_debug)
{
    debug = should_debug;
}

/**
 *  Sets color to @param
 *
 *  @param should_color bool wanna color?
 */
void set_colors(bool should_color)
{
    color = should_color;
}

void progress_log(char *msg, ...)
{
    va_list list;
    va_start(list, msg);
    if (bar_mode == 1)
    {
//        if (bar_msg != NULL)
//        {
//            bar_msg = NULL;
//        }
        
        strcpy(bar_msg, msg);
        
        printf("\033[0G\033[J");
        vprintf(msg, list);
        
        bar_mode = 0;
        
        print_bar();
    }
    else
    {
        vprintf(msg, list);
    }
    va_end(list);
}

/**
 *  Progresses a verbose message
 *
 *  @param msg message you want to display
 */
void progress_verbose(char *msg)
{
    progress_message(msg);
}

/**
 *  Progresses a debug message
 *
 *  @param msg message you want to display
 */
void progress_debug(char *msg)
{
    if (debug)
    {
        char debugmsg[200];
        if (color)
        {
            sprintf(debugmsg, "%s%s - %s : %d | DEBUG: %s%s\n", debug_color, __FILE__, __func__, __LINE__, msg, color_end);
        }
        else
        {
            sprintf(debugmsg, "%s - %s : %d | DEBUG: %s\n", __FILE__, __func__, __LINE__, msg);
        }
        
        progress_message(debugmsg);
    }
}

void progress_error(char *msg)
{
    char errormsg[200];
    if (color)
    {
        sprintf(errormsg, "%serror: %s%s", error_color, msg, color_end);
    }
    else
    {
        strcpy(errormsg, msg);
    }
    
    progress_message(errormsg);
}

/**
 *  Progresses the percentage and draws the bar
 *
 *  @param percent percent you want to display
 */
void progress_percent(int percent)
{
    if ((bar_percent < percent - 5) || (percent == 100) || percent <= 0)
    {
        bar_percent = percent;
        print_bar();
    }
}

/**
 *  Progresses a message for display
 *
 *  @param msg message you want to display
 */
void progress_message(char *msg)
{
    if (bar_mode == 1)
    {
        if (bar_msg != NULL)
        {
            free(bar_msg);
        }
        
        strcpy(bar_msg, msg);
        
        printf("\033[0G\033[J");
        printf("%s\n", msg);
        
        bar_mode = 0;
        
        print_bar();
    }
    else
    {
        printf("%s\n", msg);
    }
}

/**
 *  Prints the bar to the screen
 */
void print_bar(void)
{
    if (bar_mode == 1)
    {
        printf("\033[F\033[J");
    }
    
    bar_mode = 1;
    
    int width = determine_screen_width();
    
    if (bar_percent < 0)
    {
        // do not draw the percentage
        if (strlen(bar_msg) > (width - 5))
        {
            strncpy(bar_msg + width - 5, "...", 4); // buffer overflow gg dissident
        }
        
        printf("%s\n", bar_msg);
        fflush(stdout);
    }
    else
    {
        // draw the percentage as half of the width
        int pstart = floor(width / 2);
        int pwidth = width - pstart;
        int barwidth = ceil((pwidth - 7) * (((double) bar_percent) / 100));
        int spacewidth = (pwidth - 7) - barwidth;
        
        if (strlen(bar_msg) > (pstart - 5))
        {
            strncpy(bar_msg + pstart - 5, "...", 4);
        }
        
        printf("%s [", bar_msg);
        
        for (int i=0;i<barwidth;i++)
        {
            printf("=");
        }
        
        printf(">");
        
        for (int i=0;i<spacewidth;i++)
        {
            printf(" ");
        }
        
        printf("] %d%%\n", bar_percent);
        
        fflush(stdout);
    }
}

/**
 *  Stops displaying the bar
 */
void stop_bar(void)
{
    if (bar_mode == 1)
    {
        printf("\033[0G\033[J");
        fflush(stdout);

        bar_mode = 0;
        bar_percent = -1;
        
        free(bar_msg);
    }
}

/**
 *  Pause the bar, remove from screen, but keep data intact so we can redraw later
 */
void pause_bar(void)
{
    if (bar_mode == 1)
    {
        printf("\033[0G\033[J");
        fflush(stdout);
    }
    
    bar_mode = 0;
}