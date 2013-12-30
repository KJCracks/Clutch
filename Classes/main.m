/* This program is free software. It comes without any warranty, to
 * the extent permitted by applicable law. You can redistribute it
 * and/or modify it under the terms of the Do What The Fuck You Want
 * To Public License, Version 2, as published by Sam Hocevar. See
 * http://www.wtfpl.net/ for more details. */

/*
 Introducing Clutch, the fastest and most advanced cracking utility for the iPhone, iPod Touch, and iPad.
 
 Created by dissident at Hackulo.us (<http://hackulo.us/>)
 Credit: Nighthawk, puy0, rwxr-xr-x, Flox, Flawless, FloydianSlip, Crash-X, MadHouse, Rastignac, aulter, icefire
  ___ _       _       _
 / __\ |_   _| |_ ___| |__
 / /  | | | | | __/ __| '_ \
 / /___| | |_| | || (__| | | |
 \____/|_|\__,_|\__\___|_| |_|
 
 --------------------------------
 High-Speed iOS Decryption System
 --------------------------------
 
 Authors:
 
 dissident - The original creator of Clutch (pre 1.2.6)
 Nighthawk - Code contributor (pre 1.2.6)
 Rastignac - Inspiration and genius
 TheSexyPenguin - Inspiration
 dildog - Refactoring and code cleanup (2.0)
 
 */

/*
 * Includes
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#import  "main.h"
#import "Configuration.h"
#import "CAApplicationsController.h"
#import "install.h"
#import "CABinary.h"
#import "Cracker.h"
#import "Packager.h"
#import <sys/time.h>

#import "Foundation/Foundation.h"


/*
 * Configuration
 */

#define CLUTCH_TITLE "Clutch"
#define CLUTCH_VERSION "v2.0"
#define CLUTCH_RELEASE "ALPHA 2"

/*
 * Prototypes
 */

void print_failures(NSArray *failures, NSArray *successes);
int iterate_crack(NSArray *apps, NSArray *successes, NSArray *failures);
int cmd_version(void);
int cmd_help(void);
int cmd_crack_all(void);
int cmd_crack_updated(void);
int cmd_flush_cache(void);
int cmd_crack_exe(NSString *path);
int cmd_list_applications(NSArray *list);

/*
 * Commands
 */


int cmd_version(void)
{
    printf("%s %s (%s)\n",CLUTCH_TITLE, CLUTCH_VERSION,CLUTCH_RELEASE);
    return 0;
}

int cmd_help(void)
{
    cmd_version();
    
    printf("-----------------------------\n");
    //printf("-c          Runs configuration utility\n");
    printf("-x <path>   Crack specific executable\n");
    printf("-a          Cracks all applications\n");
    printf("-u          Cracks updated applications\n");
    printf("-f          Flush/clear cache\n");
    printf("-v          Shows version\n");
    printf("-h,-?       Shows this help\n");
    printf("\n");
    
    return 0;
}

// print_failures()
// prints the list of things that succeeded and things that failed
void print_failures(NSArray *successes, NSArray *failures)
{
    CAApplication* app;
    if(successes && [successes count]>0)
    {
        printf("Success:\n");
        
        NSEnumerator *e = [successes objectEnumerator];
        while(app = [e nextObject])
        {
            printf("%s\n",[app applicationDisplayName].UTF8String);
        }
    }
    if(failures && [failures count]>0)
    {
        printf("Failure:\n");
        
        NSEnumerator *e = [failures objectEnumerator];
        while(app = [e nextObject])
        {
            printf("%s\n",[app applicationDisplayName].UTF8String);
        }
    }
}


// iterate_crack()
// iterates over all of the apps in the NSArray list,
// prepares the app, and cracks it.
// returns a list of successes and failures

int iterate_crack(NSArray *apps, NSMutableArray *successes, NSMutableArray *failures)
{
    // Iterate over all applications
    for (CAApplication* app in apps)
    {
        // Prepare this application from the installed app
        printf("Currently cracking %s\n", app.applicationName.UTF8String);
        Cracker *cracker = [[Cracker alloc] init];
        [cracker prepareFromInstalledApp:app];
        
        
        if([cracker execute])
        {
            [successes addObject:app];
        }
        else
        {
            [failures addObject:app];
        }
        
    }
    return 0;
}

int cmd_crack_all(void)
{
    // Get list of all applications
    //NSArray *all_applications = get_application_list(FALSE, FALSE);
    NSArray *all_applications = [[CAApplicationsController sharedInstance] installedApps];
    
    // Create list for failures and successes
    NSMutableArray *failures=[[NSMutableArray alloc] init];
    NSMutableArray *successes=[[NSMutableArray alloc] init];
    
    // Iterate over all applications
    int ret = iterate_crack(all_applications, successes, failures);
    
    // Print failures and success status
    print_failures(successes,failures);
    
    [failures release];
    [successes release];
    
    return ret;
}

int cmd_crack_updated(void)
{
    // Get list of updated applications
    NSArray *update_applications;// = get_application_list(FALSE, TRUE);
    
    // Create list for failures and successes
    NSMutableArray *failures=[[NSMutableArray alloc] init];
    NSMutableArray *successes=[[NSMutableArray alloc] init];
    
    // Iterate over all applications
    int ret=iterate_crack(update_applications, successes, failures);
    
    // Print failures and success status
    print_failures(successes,failures);
    
    [failures release];
    [successes release];
    
    return ret;
}


int cmd_crack_exe(NSString *path)
{
    // Create list for failures and successes
    NSMutableArray *failures=[[NSMutableArray alloc] init];
    NSMutableArray *successes=[[NSMutableArray alloc] init];
    
    // Prepare this application from the installed app
    Cracker *cracker=[[Cracker alloc] init];
    
    NSMutableString *description=[[NSMutableString alloc] init];
    [cracker prepareFromSpecificExecutable:path returnDescription:description];
    
    int ret=0;
    if([cracker execute])
    {
        [successes addObject:description];
        ret=0;
    }
    else
    {
        [failures addObject:description];
        ret=1;
    }
    
    // Repackage IPA file
    Packager *packager=[[Packager alloc] init];
    [packager packFromSource:[path stringByDeletingLastPathComponent]
                 withOverlay:[cracker getOutputFolder]];
    
    // Print failures and success status
    print_failures(successes,failures);
    
    [failures release];
    [successes release];
    
    return ret;
}


int cmd_flush_cache(void)
{
    return 0;
}


int cmd_list_applications(NSArray *list)
{

    int index = 1;
    
    printf("\n");
    
    for (CAApplication* application in list) {
        printf("%d) \033[1;3%dm%s\033[0m \n", index, 5 + ((index + 1) % 2), application.applicationName.UTF8String);
        index++;
    }
    
    printf("\n");
    
    return 0;
}

/*
 * Main Function
 */

int main(int argc, const char *argv[])
{
    // Prepare command line options
    int ret=0;
    
    printf("\n");
    
    // check that we are root
    if (getuid() != 0)
    {
        printf("You need to be root to use Clutch.\n");
        
        return 1;
    }
    
    // this line gives me
    NSArray *arguments = [[NSProcessInfo processInfo] arguments];
    
    int cnt = (int)[arguments count];
    
    for(int idx = 0;idx < cnt; idx++)
    {
        // Process each command line option
        NSString *arg = [arguments objectAtIndex:idx];
        
        if([arg isEqualToString:@"/usr/bin/Clutch"] && [arguments count] == 1)
        {
            // show help & list applications
            cmd_help();
            NSArray *apps = [[CAApplicationsController sharedInstance] installedApps];
            
            if (apps == nil)
            {
                printf("Error finding applications!\n");
            } else if ([apps count] == 0)
            {
                printf("No encrypted applications found\n");
            } else
            {
                cmd_list_applications(apps);
            }
            
            break;
        }
        
        if([arg isEqualToString:@"-a"])
        {
            // Crack all applications
            ret = cmd_crack_all();
        }
        else if([arg isEqualToString:@"-u"])
        {
            // Crack updated applications
            ret = cmd_crack_updated();
        }
        else if([arg isEqualToString:@"-f"])
        {
            // Flush caches
            ret = cmd_flush_cache();
        }
        else if([arg isEqualToString:@"-v"])
        {
            // Display version string
            ret = cmd_version();
        }
        else if([arg isEqualToString:@"-x"])
        {
            // Crack specific executable
            
            // Get path argument
            idx++;
            if(idx>=cnt)
            {
                printf("-x requires a 'path' argument");
                return 1;
            }
            NSString *path = [arguments objectAtIndex:idx];
            
            ret = cmd_crack_exe(path);
        }
        else if([arg isEqualToString:@"-h"] || [arg isEqualToString:@"-?"])
        {
            // Display help
            ret = cmd_help();
        }
        //else if ([arg isEqualToString:@""])
        else
        {
            if (argc > 1) {
                NSMutableArray* apps_to_crack = [[NSMutableArray alloc] init];
                for (int i = 1; i<argc; i++) {
                    printf("argv: %s", argv[i]);
                    for (CAApplication* app in [[CAApplicationsController sharedInstance] installedApps]) {
                        if ([app.applicationName caseInsensitiveCompare:[NSString stringWithCString:argv[i] encoding:NSASCIIStringEncoding]] == NSOrderedSame) {
                            printf("Queuing application %s\n", app.applicationName.UTF8String);
                            [apps_to_crack addObject:app];
                        }
                    }
                }
                NSMutableArray *failures=[[NSMutableArray alloc] init];
                NSMutableArray *successes=[[NSMutableArray alloc] init];
                
                iterate_crack(apps_to_crack, successes, failures);
                print_failures(successes, failures);
                
            }
            // Unknown command line option
            printf ("unknown option '%s'\n", [arg UTF8String]);
            return 1;
        }
    }
    
    return ret;
}
