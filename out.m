#import "out.h"

int determine_screen_width (void) {
    int fd;
    struct winsize wsz;
    
    fd = fileno (stderr);
    if (ioctl (fd, TIOCGWINSZ, &wsz) < 0)
        return 0;
    
    return wsz.ws_col;
}

// mode of bar, 0 = inactive, 1 = active
int bar_mode = 0;
// percent of bar, negative is no bar
int bar_percent = -1;
char *bar_msg = NULL;

/**
 progress_message places an "active" message for what Clutch is currently doing
 */
void progress_message(char *msg) {
    if ([[ClutchConfiguration getValue:@"ProgressBar"] isEqualToString:@"NO"]) {
        return;
    }
    
    if (bar_msg != NULL)
        free(bar_msg);
    bar_msg = malloc(strlen(msg) + 1);
    strcpy(bar_msg, msg);
    print_bar();
}

/**
 progress_percent places a percentage for the task being done by Clutch
 */
void progress_percent(int percent) {
    if ([[ClutchConfiguration getValue:@"ProgressBar"] isEqualToString:@"NO"]) {
        return;
    }
    
    if ((bar_percent < percent - 5) || (percent == 100) || (percent < 0)) {
        bar_percent = percent;
        print_bar();
    }
}

/**
 progress_event places an event in the log
 */
void progress_event(char *text) {
    if ([[ClutchConfiguration getValue:@"ProgressBar"] isEqualToString:@"NO"]) {
        printf("%s\n", text);
        return;
    }
    if (bar_mode == 1) {
        // if the bar is there, we need to remove it, print the event, and then print the bar again
        printf("\033[0G\033[J");
        printf("%s\n", text);
        bar_mode = 0;
        print_bar();
    } else {
        printf("%s\n", text);
    }
    fflush(stdout);
}

/**
 print the progress bar
 */
void print_bar(void) {
    if (bar_mode == 1) {
        printf("\033[0G\033[J");
    }
    bar_mode = 1;
    
    int width = determine_screen_width();
    if (bar_percent < 0) {
        // do not draw the percentage
        if (strlen(bar_msg) > (width - 5)) {
            strncpy(bar_msg + width - 5, "...", 4);
        }
        printf("%s", bar_msg);
        fflush(stdout);
    } else {
        // draw the percentage as half of the width
        int pstart = floor(width / 2);
        int pwidth = width - pstart;
        int barwidth = ceil((pwidth - 7) * (((double) bar_percent) / 100));
        // printf("bar percent: %f\n", ((double) bar_percent) / 100); exit(0);
        int spacewidth = (pwidth - 7) - barwidth;
        if (strlen(bar_msg) > (pstart - 5)) {
            strncpy(bar_msg + pstart - 5, "...", 4);
        }
        printf("%s [", bar_msg);
        for (int i=0;i<barwidth;i++) {
            printf("=");
        }
        for (int i=0;i<spacewidth;i++) {
            printf(" ");
        }
        printf("] %d%%", bar_percent);
        
        fflush(stdout);
    }
}

/**
 * pause the bar (leave data intact so we can re-render later)
 */
void pause_bar(void) {
    if (bar_mode == 1) {
        printf("\033[0G\033[J");
        fflush(stdout);
    }
    bar_mode = 0;
}

/**
 stop the progress bar
 */
void stop_bar(void) {
    if (bar_mode == 1) {
        printf("\033[0G\033[J");
        fflush(stdout);
        bar_mode = 0;
        free(bar_msg);
        bar_msg = NULL;
        bar_percent = -1;
    }
}