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

/* Prototypes */
const static int NOT_YET_IMPLEMENTED = 2;
struct timeval start, end; // Used to time execution

int diff_ms(struct timeval t1, struct timeval t2);

int cmd_version();
int cmd_help();
int cmd_crack_app(Application *application, Cracker *cracker);
int cmd_crack_all_apps(NSArray *applications, Cracker *cracker);
int cmd_list_applications();
int cmd_run_configuration();

/* Functions */

int diff_ms(struct timeval t1, struct timeval t2)
{
    return (int)((((t1.tv_sec - t2.tv_sec) * 1000000) + (t1.tv_usec - t2.tv_usec)) / 1000);
}

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
    printf("-d, --debug                       Shows debug messages\n");
    printf("--no-64                           Skips arm64 portions\n");
    printf("\n");
    
    return 1;
}

int cmd_crack_app(Application *application, Cracker *cracker)
{
    BOOL success = [cracker crackApplication:application];
    
    if (success)
    {
        return EXIT_SUCCESS;
    }
    
    return EXIT_FAILURE;
}

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

int cmd_list_applications(NSArray *applications)
{
    int counter = 1;
    for (Application *app in applications)
    {
        printf("%d) %s ", counter, app.displayName.UTF8String);
        counter++;
    }
    
    return EXIT_SUCCESS;
}

int cmd_run_configuration()
{
    return NOT_YET_IMPLEMENTED;
}

int main(int argc, char * argv[]) {
    @autoreleasepool {
        int returnValue = 0;
        gettimeofday(&start, NULL);
        
        /* Check for priviledge level */
        if (getuid() != 0)
        {
            /* Clutch needs to be root */
            printf("Please re-run Clutch as root user.\n");
            returnValue = EXIT_FAILURE;
            
            goto endMain;
        }
        
        printf("Clutch 2.0 pre-alpha\n");
        
        /* Parse Environment Options */
        NSDictionary *environment = [[NSProcessInfo processInfo] environment];
        
        /* Parse CLI arguments */
        NSArray *arguments = [[NSProcessInfo processInfo] arguments];
        NSString *binaryName = arguments[0];
        
        NSArray *applications = [ApplicationLister applications];
        Cracker *cracker = [Cracker sharedSingleton];
        
        /* Interate through arguments */
        for (int i = 0; i < arguments.count; i++)
        {
            NSString *currentArgument = arguments[i];
            
            /* List installed applications */
            if (arguments.count == 1 && [currentArgument isEqualToString:binaryName])
            {
                returnValue = cmd_list_applications(applications);
                
                goto endMain;
            }
            
            /* Skip onto the next argument */
            if ([currentArgument isEqualToString:binaryName])
            {
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
                for (Application *app in applications)
                {
                    returnValue = cmd_crack_app(app, cracker);
                }
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
                }
                
                returnValue = cmd_crack_app(applicationToCrack, cracker);
                goto endMain;
            }
        }
        
    endMain:
        gettimeofday(&end, NULL);
        int timeElapsed = diff_ms(end, start);
        printf("\nTime Elapsed: %f\n", ((timeElapsed + 500.0f) / 1000.0f));
        return returnValue;
    }
}