/*
 Copyright (C) 2014  Kim Jong-Cracks
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as
 published by the Free Software Foundation, either version 3 of the
 License, or (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU Affero General Public License for more details.
 
 You should have received a copy of the GNU Affero General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

/*
....___ _       _       _
.../ __\ |_   _| |_ ___| |__
../ /  | | | | | __/ __| '_ \
./ /___| | |_| | || (__| | | |
.\____/|_|\__,_|\__\___|_| |_|
 
 --------------------------------
 High-Speed iOS Decryption System
 --------------------------------
 
 Authors:
 ttwj
 NinjaLikesCheez

 Zorro - fixes, features, code (1.4)
 dissident - The original creator of Clutch (pre 1.2.6)
 Nighthawk - Code contributor (pre 1.2.6)
 Rastignac - Inspiration and genius
 TheSexyPenguin - Inspiration (not really)
 dildog - Refactoring and code cleanup (2.0)
 
 Thanks to: Nighthawk, puy0, rwxr-xr-x, Flox, Flawless, FloydianSlip, Crash-X, MadHouse, Rastignac, aulter, icefire
*/

/* Imports */

#import <UIKit/UIKit.h>

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/time.h>

#import "Application.h"
#import "Cracker.h"
#import "out.h"

#define CLUTCH_TITLE @"Clutch"
#define CLUTCH_MAJOR_VERSION 2
#define CLUTCH_MINOR_VERSION 0
#define CLUTCH_GIT_VERSION @"git-1"
#define CLUTCH_DEBUG 1


/* Prototypes */
const static int NOT_YET_IMPLEMENTED = 2;
struct timeval start, end; // Used to time execution

int get_ms_difference(struct timeval t1, struct timeval t2);

int cmd_version();
int cmd_help();
int cmd_crack_app(Application *application, Cracker *cracker);
int cmd_crack_all_apps(NSArray *applications, Cracker *cracker);
int cmd_list_applications();
int cmd_run_configuration();

/* Functions */

/**
 *  Get the difference in milliseconds between two timevals
 *
 *  @param t1 timeval struct 'end'
 *  @param t2 timeval struct 'start'
 *
 *  @return difference between t1 and t2 in milliseconds
 */
int get_ms_difference(struct timeval t1, struct timeval t2)
{
    return (int)((((((t1.tv_sec - t2.tv_sec) * 1000000) + (t1.tv_usec - t2.tv_usec)) / 1000) + 500.0f) / 1000.0f);
}

/**
 *  Prints the help menu (in English - eventually this will be localized)
 *
 *  @return EXIT_SUCCESS
 */
int cmd_help()
{
    printf("Clutch Help\n");
    printf("----------------------\n");
    printf("-c                            Runs configuration utility\n");
    printf("-a                            Cracks all applications\n");
    printf("-u                            Cracks updated applications\n");
    printf("-f                            Clears cache\n");
    printf("-v                            Shows version\n");
    printf("-i <IPA> <Binary> <OutBinary> Installs IPA and cracks it\n");
    printf("-e <InBinary> <OutBinary>     Cracks specific already-installed\n"
           "                              executable or one that has been\n"
           "                              scp'd to the device. (advanced usage)\n");
    printf("--debug                       Shows debug messages\n");
    printf("--no-colors | --no-colours    Removes colors from output");
    printf("\n");
    
    return EXIT_SUCCESS;
}

/**
 *  Begin the cracking of an Application object
 *
 *  @param application Application object you want cracked
 *  @param cracker     Cracker singleton
 *
 *  @return EXIT_SUCCESS if application was cracked, else EXIT_FAILURE
 */
int cmd_crack_app(Application *application, Cracker *cracker)
{
    if (application.plugins)
    {
        for (Plugin *plugin in application.plugins)
        {
            printf("Found plugin");
        }
    }
    
    BOOL success = [cracker crackApplication:application];
    
    if (success)
    {
        return EXIT_SUCCESS;
    }
    
    return EXIT_FAILURE;
}

/**
 *  Crack an array of Application objects
 *
 *  @param applications NSArray of Application objects
 *  @param cracker      Cracker singleton
 *
 *  @return EXIT_SUCCESS if applications were cracked, else EXIT_FAILURE
 */
int cmd_crack_all_apps(NSArray *applications, Cracker *cracker)
{
    for (Application *app in applications)
    {
        int success = cmd_crack_app(app, cracker);
        
        if (!success)
        {
            printf("Error: Failed to cracked application: %s", app.displayName.UTF8String);
        }
    }
    
    return EXIT_FAILURE;
}

/**
 *  List Applications to stdout
 *
 *  @param applications NSArray of application objects to be printed (application.displayName)
 *
 *  @return EXIT_SUCCESS
 */
int cmd_list_applications(NSArray *applications)
{
    int counter = 1;
    for (Application *app in applications)
    {
        printf("%d) \033[1;3%dm%-s\033[0m  ", counter, 5 + ((counter + 1) % 2), app.displayName.UTF8String);
        counter++;
    }
    
    printf("\n");
    
    return EXIT_SUCCESS;
}

/**
 *  Runs the configuration utility
 *
 *  @return NOT_YET_IMPLEMENTED
 */
int cmd_run_configuration()
{
    return NOT_YET_IMPLEMENTED;
}

/**
 *  Prints the version of Clutch
 *
 *  @return EXIT_SUCCESS
 */
int cmd_show_version()
{
    printf("\n%s %d.%d-%s\n", CLUTCH_TITLE.UTF8String, CLUTCH_MAJOR_VERSION, CLUTCH_MINOR_VERSION, CLUTCH_GIT_VERSION.UTF8String);
    
    return EXIT_SUCCESS;
}


int main(int argc, char * argv[])
{
    @autoreleasepool
    {
        int returnValue = 0;
        gettimeofday(&start, NULL);
        
        /* Check for priviledge level */
        if (getuid() != 0)
        {
            /* Clutch needs to be root */
            printf("Please re-run %s as root user.\n", CLUTCH_TITLE.UTF8String);
            return EXIT_FAILURE;
        }
        
        /* Parse Environment Options */
        NSDictionary *environment = [[NSProcessInfo processInfo] environment];
        
        /* Parse CLI arguments */
        NSMutableArray *arguments = [[[NSProcessInfo processInfo] arguments] mutableCopy];
        NSString *binaryName = arguments[0];
        
        NSArray *applications = [ApplicationLister applications];
        Cracker *cracker = [Cracker sharedSingleton];
        
        /* Set globals up */
        if ([arguments containsObject:@"--debug"])
        {
            set_debug(true);
            [arguments removeObject:@"--debug"];
        }
        
        if ([arguments containsObject:@"--no-colors"] || [arguments containsObject:@"--no-colours"])
        {
            set_colors(false);
            
            if ([arguments containsObject:@"--no-colors"])
                [arguments removeObject:@"--no-colors"];
            if ([arguments containsObject:@"--no-colours"])
                [arguments removeObject:@"--no-colours"];
        }
        
        /* Interate through arguments */
        for (int i = 0; i < arguments.count; i++)
        {
            NSString *currentArgument = arguments[i];
            
            if ([currentArgument isEqualToString:binaryName])
            {
                /* List installed applications */
                if (arguments.count == 1)
                {
                    returnValue = cmd_list_applications(applications);
                    
                    goto endMain;
                }
                
                /* Skip onto the next argument */
                continue;
            }
            
            /* Parse and apply logic to command options */
            if ([currentArgument isEqualToString:@"-c"])
            {
                /* Run Configuration */
                returnValue = cmd_run_configuration();
                goto endMain;
            }
            else if ([currentArgument isEqualToString:@"-a"])
            {
                /* Crack All Applications */
                for (Application *app in applications)
                {
                    returnValue = cmd_crack_app(app, cracker);
                }
            }
            else if ([currentArgument isEqualToString:@"-v"])
            {
                /* Show version information */
                returnValue = cmd_show_version();
            }
            else
            {
                /* Application Identifier i.e. typed in to crack x */
                __block Application *applicationToCrack;
                [applications enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    Application *app = (Application*)obj;
                    
                    /* We can add any type of identifer we want here */
                    if ([app.displayName caseInsensitiveCompare:currentArgument] == NSOrderedSame || [app.name caseInsensitiveCompare:currentArgument] == NSOrderedSame)
                    {
                        applicationToCrack = app;
                        *stop = YES;
                    }
                    else if ([app.bundleID caseInsensitiveCompare:currentArgument] == NSOrderedSame)
                    {
                        applicationToCrack = app;
                        *stop = YES;
                    }
                    else if (applications.count >= (currentArgument.intValue - 1))
                    {
                        applicationToCrack = applications[currentArgument.intValue - 1];
                        *stop = YES;
                    }
                }];
                
                if (!applicationToCrack)
                {
                    printf("Unrecogised Identifier: %s.\n", currentArgument.UTF8String);
                    goto endMain;
                }
                
                returnValue = cmd_crack_app(applicationToCrack, cracker);
                goto endMain;
            }
        }
        
    endMain:
        [arguments release];
        gettimeofday(&end, NULL);
        int timeElapsed = get_ms_difference(end, start);
        printf("\nTime Elapsed: %f\n", ((timeElapsed + 500.0f) / 1000.0f));
        return returnValue;
    }
}