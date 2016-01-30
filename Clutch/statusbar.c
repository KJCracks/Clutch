/**
* \file
* \author Trevor Fountain
* \author Johannes Buchner
* \author Erik Garrison
* \date 2010-2014
* \copyright BSD 3-Clause
*
* statusbar -- a C class (by convention) for displaying progress
* on the command line (to stderr).
*/
#include "statusbar.h"

statusbar *statusbar_new_with_format(const char *label, const char *format)
{
  statusbar *new = malloc(sizeof(statusbar));
  new->label = label;
  new->start_time = time(0);
  new->format_length = strlen(format);
  new->format = malloc( sizeof(char) * (new->format_length + 1) );
  strncpy(new->format, format, new->format_length);
  new->format_index = 0;
  new->last_printed = 0;

  return new;
}

statusbar *statusbar_new(const char *label)
{
  return statusbar_new_with_format(label, "-\\|/");
}

void statusbar_free(statusbar *bar)
{
  // We malloc'd a string, so let's be sure to free it...
  free(bar->format);
  // ...before we free the struct itself.
  free(bar);

  return;
}

void statusbar_inc(statusbar *bar)
{
  bar->format_index++;
  if (bar->format_index >= bar->format_length) {
    bar->format_index = 0;
  }
  statusbar_draw(bar);

  return;
}

void statusbar_draw(statusbar *bar)
{
  // Erase the last draw. If anything else has been printed to stderr,
  // things are going to look mighty interesting...
  for(int i=0; i < bar->last_printed; i++) {
    fprintf(stderr,"\b");
  }

  fprintf(
        stderr,
        "%s: %c%n",
        bar->label,
        bar->format[bar->format_index],
        &(bar->last_printed)
    );

  return;
}

void statusbar_finish(statusbar *bar)
{
  // Draw one more time, with the actual time to completion.
  unsigned int offset = time(0) - (bar->start_time);

  // Convert the time to display into HHH:MM:SS
  unsigned int h = offset/3600;
  offset -= h*3600;
  unsigned int m = offset/60;
  offset -= m*60;
  unsigned int s = offset;

  // Erase the last draw
  for(int i=0; i < bar->last_printed; i++) {
    fprintf(stderr,"\b");
  }

  // Calculate number of spaces for right-justified time to completion
  fprintf(stderr,"%s: %3d:%02d:%02d%n",bar->label,h,m,s,&(bar->last_printed));
  for(int i=0; i < bar->last_printed; i++) {
    fprintf(stderr,"\b");
  }

  // Print right-justified
  fprintf(stderr,"%s: ",bar->label);
  for(int i=0; i < (80 - (bar->last_printed)); i++) {
    fprintf(stderr," ");
  }
  fprintf(stderr,"%3d:%02d:%02d\n",h,m,s);

  // We've finished with this statusbar, so go ahead and free it.
  statusbar_free(bar);

  return;
}
