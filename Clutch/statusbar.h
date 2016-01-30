/**
* \file
* \author Trevor Fountain
* \author Johannes Buchner
* \author Erik Garrison
* \date 2010-2014
* \copyright BSD 3-Clause
*
* statusbar -- a C class (by convention) for displaying indefinite progress
* on the command line (to stderr).
*/

#ifndef STATUSBAR_H
#define STATUSBAR_H

#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/**
 * Statusbar data structure (do not modify or create directly)
 */
typedef struct _statusbar_t
{
    unsigned int start_time;
    const char *label;
    int format_index;
    int format_length;
  char *format;
  int last_printed;
} statusbar;

/// Create a new statusbar with the specified label and format string
statusbar *statusbar_new_with_format(const char *label, const char *format);

/// Create a new statusbar with the specified label
statusbar *statusbar_new(const char *label);

/// Free an existing progress bar. Don't call this directly; call *statusbar_finish* instead.
void statusbar_free(statusbar *bar);

/// Increment the given statusbar.
void statusbar_inc(statusbar *bar);

/// Finalize (and free!) a statusbar. Call this when you're done.
void statusbar_finish(statusbar *bar);

/// Draw a statusbar to the screen. Don't call this directly,
/// as it's called internally by *statusbar_inc*.
void statusbar_draw(statusbar *bar);

#endif
