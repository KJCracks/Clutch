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
 ___ _       _       _
 / __\ |_   _| |_ ___| |__
 / /  | | | | | __/ __| '_ \
 / /___| | |_| | || (__| | | |
 \____/|_|\__,_|\__\___|_| |_|
 
 --------------------------------
 High-Speed iOS Decryption System
 --------------------------------
 
 Authors:
 
 ttwj - post 1.2.6
 NinjaLikesCheez - post 1.2.6
 Zorro - fixes, features, code (1.4)
 
 dissident - The original creator of Clutch (pre 1.2.6)
 Nighthawk - Code contributor (pre 1.2.6)
 Rastignac - Inspiration and genius
 TheSexyPenguin - Inspiration (not really)
 dildog - Refactoring and code cleanup (2.0)
 
 Thanks to: Nighthawk, puy0, rwxr-xr-x, Flox, Flawless, FloydianSlip, Crash-X, MadHouse, Rastignac, aulter, icefire
 
 */

/*
 * Includes
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#import <sys/time.h>

#import "ApplicationLister.h"
#import "install.h"
#import "Binary.h"
#import "Cracker.h"
#import "Localization.h"
#import "API.h"

/*
 * Protypes
 */

BOOL crack = FALSE;
BOOL readCompression;
struct timeval start, end;
int yopa_enabled, get_info;

NSMutableArray *successfulCracks;
NSMutableArray *failedCracks;

int diff_ms(struct timeval t1, struct timeval t2);
BOOL check_version();
static NSString *get_compare_with();
void print_results();

void cmd_version();
void cmd_help();
void cmd_list_applications(NSArray *applications);
int cmd_crack_all(NSArray *applications);
int cmd_crack_app(Application *app, int yopa_enabled);
int cmd_crack_specific_binary(NSString *inbinary, NSString *outbinary);


/*
 * Functions
 */

int diff_ms(struct timeval t1, struct timeval t2)
{
    return (int)((((t1.tv_sec - t2.tv_sec) * 1000000) +
                  (t1.tv_usec - t2.tv_usec)) / 1000);
}

BOOL check_version()
{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://kjcracks.github.io/Clutch/current_build"] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    NSURLResponse* response = [[NSURLResponse alloc] init];
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    int build_version = [dataString intValue];
    
    [dataString release];
    
    if (build_version > CLUTCH_BUILD)
    {
        MSG(CLUTCH_DEV_NOT_UP_TO_DATE);
        
        return FALSE;
    }
    else
    {
        MSG(CLUTCH_DEV_UP_TO_DATE);
    }
    
    return TRUE;
}

static NSString* get_compare_with()
{
    static NSString* compare;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        if ([[[Preferences sharedInstance] objectForKey:@"ListWithDisplayName"] isEqualToString:@"DIRECTORY"])
        {
            compare = @"RealUniqueID";
        }
        else if ([[Preferences sharedInstance] boolForKey:@"ListWithDisplayName"]) {
            compare = @"ApplicationDisplayName";
        }
        else {
            compare = @"ApplicationName";
        }
    });
    
    return compare;
}

void print_results()
{
    if (successfulCracks.count > 0)
    {
        MSG(COMPLETE_APPS_CRACKED);
        
        for (int i = 0; i < [successfulCracks count]; i++)
        {
            printf("\033[0;32m%s\033[0m\n", [successfulCracks[i] UTF8String]);
        }
    }
    
    if (failedCracks.count > 0)
    {
        MSG(COMPLETE_APPS_FAILED);
        
        for (int i = 0; i < [failedCracks count]; i++)
        {
            printf("\033[0;32m%s\033[0m\n", [failedCracks[i] UTF8String]);
        }
    }
    
    MSG(COMPLETE_TOTAL, (int)[successfulCracks count], (int)[failedCracks count]);
}

void cmd_version()
{
    if (CLUTCH_DEV == 1) {
        fprintf(stderr, "%s %s (%s)\n", CLUTCH_TITLE, CLUTCH_VERSION, CLUTCH_RELEASE);
    }
    else {
        fprintf(stderr, "%s %s\n", CLUTCH_TITLE, CLUTCH_VERSION);
    }
    fprintf(stderr, "---------------------------------\n");
}

void cmd_help()
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
    //printf("--yopa                        Creates a YOPA package\n");
    //printf("-d                            Shows debug messages\n");
    printf("\n");
}

void cmd_list_applications(NSArray *applications)
{
    int cindex = 1;
    
    if ([[Preferences sharedInstance] numberBasedMenu])
    {
        printf("\n");
    }
    
    NSString* comparedValue;
    
    for (Application* app in applications)
    {
        comparedValue = [app->_info objectForKey:get_compare_with()];
        
        if ([[Preferences sharedInstance] numberBasedMenu])
        {
            printf("%d) \033[1;3%dm%s\033[0m \n", cindex, 5 + ((cindex + 1) % 2), [comparedValue UTF8String]);
            cindex++;
        }
        else
        {
            printf("\033[1;3%dm%s\033[0m ", 5 + ((cindex + 1) % 2), [comparedValue UTF8String]);
            cindex++;
        }
    }
    
    printf("\n");
}

int cmd_crack_all(NSArray *applications)
{
    NSString *ipapath;
    
    for (Application* app in applications) {
        MSG(CRACKING_APPNAME, app.applicationName);
        
        Cracker *cracker = [[Cracker alloc] init];
        [cracker prepareFromInstalledApp:app];
        
        ipapath = [cracker generateIPAPath];
        
        if ([cracker execute])
        {
            gettimeofday(&end, NULL);
            
            crack = TRUE;
            
            printf("\t%s\n", [ipapath UTF8String]);
            
            [successfulCracks addObject:app.applicationName];
        }
        else
        {
            printf("Failed.\n");
            
            [failedCracks addObject:app.applicationName];
        }
        
        [cracker release];
    }
    
    print_results();
    
    return 0;
}

int cmd_crack_specific_binary(NSString *inbinary, NSString *outbinary)
{
    MSG(CRACKING_APPNAME, inbinary);
    
    [[NSFileManager defaultManager] removeItemAtPath:outbinary error:nil];
    
    Binary* binary = [[Binary alloc] initWithBinary:inbinary];
    
    DEBUG(@"outbinary %@", outbinary);
    
    [binary crackBinaryToFile:outbinary error:nil];
    
    DEBUG(@"apparently crack was ok!?");
    
    [binary release];
    
    print_results();
    return 0;
}


int cmd_crack_app(Application *app, int yopa_enabled)
{
    MSG(CRACKING_APPNAME, app.applicationName);
    
    Cracker *cracker = [[Cracker alloc] init];
    [cracker prepareFromInstalledApp:app];
    [cracker yopaEnabled:yopa_enabled];
    
    NSString *ipapath = [cracker generateIPAPath];
    
    if ([cracker execute])
    {
        gettimeofday(&end, NULL);
        
        
        crack = TRUE;
        
        printf("\t%s\n", [ipapath UTF8String]);
        
        [successfulCracks addObject:app.applicationName];
        [cracker release];
        
        int dif = diff_ms(end,start);
        float sec = ((dif + 500.0f) / 1000.0f);
        
        MSG(COMPLETE_ELAPSED_TIME, sec);
        
        print_results();
        
        return 0;
    }
    else
    {
        [failedCracks addObject:app.applicationName];
        
        printf("Failed.\n");
        
        [cracker release];
        
        print_results();
        
        return 1;
    }
    
    [cracker release]; // Shouldn't get hurrr
    
    return 0;
    
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        int retVal = 0;
        
        if (getuid() != 0) // Clutch needs to be root
        {
            if ([Localization sharedInstance]->setuidPerformed) {
                //setuid to root needs chown:root, dumb users won't udnerstand
                printf("Localization cache obtained, please re-run Clutch\n");
                printf("已获取本地化缓存, 请重新运行\n");
                goto endMain;
            }
            
            MSG(CLUTCH_PERMISSION_ERROR);
            
            goto endMain;
        }
        
        if (CLUTCH_DEV == 1)
        {
            
            if (![[[[NSProcessInfo processInfo] environment] objectForKey:@"CLUTCH_IGNORE_DEV"] isEqualToString:@"YES"]) {
                MSG(CLUTCH_DEV_CHECK_UPDATE);
                
                if (!check_version())
                {
                    // Clutch needs updating.
                    return retVal;
                }
            }
        }
        
        NSString* clutch_conf = [[[NSProcessInfo processInfo] environment] objectForKey:@"CLUTCH_CONF"];
        if (clutch_conf.length > 0) {
            printf("\nusing custom configuration..\n");
            [Preferences setConfigPath:clutch_conf];
        }
        
        gettimeofday(&start, NULL);
        
        [[Localization sharedInstance] checkCache];
        
        successfulCracks = [[[NSMutableArray alloc] init] autorelease];
        failedCracks = [[[NSMutableArray alloc] init] autorelease];
        
        cmd_version();
        
        NSArray *arguments = [[NSProcessInfo processInfo] arguments];
        NSArray *applist = [[ApplicationLister sharedInstance] installedApps];
        
        if (applist == NULL)
        {
            MSG(CLUTCH_NO_APPLICATIONS);
        }
        
        
        for (int i = 0; i < arguments.count; i++)
        {
            NSString *arg = arguments[i];
            
            if (arguments.count == 1 && [arg isEqualToString:arguments[0]])
            {
                applist = [[ApplicationLister sharedInstance] installedApps];
                // User just typed `Clutch` list applications
                cmd_list_applications(applist);
                
                goto endMain;
            }
            
            if ([arg isEqualToString:@"-i"] || [arg isEqualToString:@"-install"])
            {
                if (arguments.count < 3)
                {
                    printf("%s %s requires 3 arguments (%d found).\n", argv[0], [arg UTF8String], (int)(arguments.count - 2));
                    
                    return retVal;
                }
                
                NSString *ipa = arguments[2];
                NSString *binary = arguments[3];
                NSString *outbinary = arguments[4];
                
                Install *install = [[Install alloc] initWithIPA:ipa withBinary:binary];
                [install installIPA];
                [install crackWithOutBinary:outbinary];
                [install release];
                goto endMain;
                
            }
            //else if ([arg isEqualToString:@"-d"] || [arg isEqualToString:@"-debug"]) {
               
            //}
            else if ([arg isEqualToString:@"-a"] || [arg isEqualToString:@"-all"])
            {
                applist = [[ApplicationLister sharedInstance] installedApps];
                retVal = cmd_crack_all(applist);
                MSG(CLUTCH_CRACKING_ALL);
            }
            else if ([arg isEqualToString:@"-f"] || [arg isEqualToString:@"-flush"])
            {
                [[NSFileManager defaultManager] removeItemAtPath:@"/var/cache/clutch.plist" error:NULL];
                
                printf("Done.");
                
                goto endMain;
            }
            else if ([arg isEqualToString:@"-v"] || [arg isEqualToString:@"-version"])
            {
                printf("%u", CLUTCH_BUILD);
                
                goto endMain;
            }
            else if ([arg isEqualToString:@"-c"] || [arg isEqualToString:@"-C"] || [arg isEqualToString:@"-config"])
            {
                [[Preferences sharedInstance] setupConfig];
                
                goto endMain;
            }
            else if ([arg isEqualToString:@"-u"])
            {
                //get updated apps only
                applist = [[ApplicationLister sharedInstance] modifiedApps];
                if ([applist count] == 0)
                {
                    printf("You have no updated apps!\n");
                    retVal = 0;
                    goto endMain;
                }
                
                printf("Cracking all updated apps!\n");
                retVal = cmd_crack_all(applist);
                goto endMain;
            }
            else if ([arg isEqualToString:@"-e"])
            {
                if (arguments.count != 4)
                {
                    printf("%s %s requires 2 arguments (%d found).\n", argv[0], [arg UTF8String], (int)(arguments.count - 2));
                    return retVal;
                }
                
                NSString *binary = arguments[2];
                NSString *outbinary = arguments[3];
                retVal = cmd_crack_specific_binary(binary, outbinary);
                goto endMain;
            }

            else if ([arg isEqualToString:@"-h"] || [arg isEqualToString:@"-help"])
            {
                cmd_help();
                
                goto endMain;
            }
            else if ([arg isEqualToString:@"--yopa"])
            {
                MSG(CLUTCH_ENABLED_YOPA);
                yopa_enabled = 1;
            }
            else if ([arg isEqualToString:@"--info"])
            {
                get_info = 1;
                DEBUG(@"getting info wow");
            }
            else
            {
                if ([arg isEqualToString:arguments[0]])
                {
                    continue;
                }
                
                NSString* _arg = arg;
                if ([[Preferences sharedInstance] numberBasedMenu])
                {
                    int number = [arg intValue] - 1;
                    Application* app = applist[number];
                    
                    retVal = cmd_crack_app(app, yopa_enabled);
                }
                else
                {
                    
                    Application* crackApp = NULL;
                    
                    for (Application *app in applist)
                    {
                        
                        if ([[[Preferences sharedInstance] objectForKey:@"ListWithDisplayName"] isEqualToString:@"DIRECTORY"])
                        {
                            if ([app.applicationDirectory caseInsensitiveCompare:_arg] == NSOrderedSame)
                            {
                                crackApp = app;
                                break;
                            }
                        }
                        else if ([[Preferences sharedInstance] boolForKey:@"ListWithDisplayName"])
                        {
                            if ([app.applicationDisplayName caseInsensitiveCompare:_arg] == NSOrderedSame)
                            {
                                crackApp = app;
                                break;
                            }
                            
                        }
                        else
                        {
                            if ([app.applicationExecutableName caseInsensitiveCompare:_arg] == NSOrderedSame)
                            {
                                crackApp = app;
                                break;
                            }
                        }
                    }
                    
                    if (!crackApp)
                    {
                        printf("error: Could not find application %s!\n\n", [_arg UTF8String]);
                        retVal = 1;
                        goto endMain;
                    }
                    
                    if (get_info == 1)
                    {
                        API* api = [[API alloc] initWithApp:crackApp];
                        [api setEnvironmentArgs];
                        [api release];
                        retVal = 0;
                        goto endMain;
                    }
                    
                    retVal = cmd_crack_app(crackApp, yopa_enabled);
                    goto endMain;
                }
            }
        }
        
        goto endMain;
        
    endMain:
        return retVal;
    }
}


