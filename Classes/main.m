/*

 This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
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
 
 dissident - The original creator of Clutch (pre 1.2.6)
 Nighthawk - Code contributor (pre 1.2.6)
 Rastignac - Inspiration and genius
 TheSexyPenguin - Inspiration
 dildog - Refactoring and code cleanup (2.0)
 Zorro - fixes, features, code (1.4)
 
 Thanks to: Nighthawk, puy0, rwxr-xr-x, Flox, Flawless, FloydianSlip, Crash-X, MadHouse, Rastignac, aulter, icefire
 
 */

/*
 * Includes
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#import <sys/time.h>

#import "CAApplicationsController.h"
#import "install.h"
#import "CABinary.h"
#import "Cracker.h"
#import "Packager.h"
#import "Localization.h"

/*
 * Protypes
 */

BOOL crack = FALSE;
BOOL readCompression;
struct timeval start, end;

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
int cmd_crack_app(CAApplication *app, int yopa_enabled);


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
        if ([[[Prefs sharedInstance] objectForKey:@"ListWithDisplayName"] isEqualToString:@"DIRECTORY"])
        {
            compare = @"RealUniqueID";
        }
        else if ([[Prefs sharedInstance] boolForKey:@"ListWithDisplayName"]) {
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
    if (successfulCracks && successfulCracks.count > 0)
    {
        MSG(COMPLETE_APPS_CRACKED);
        
        for (int i = 0; i < [successfulCracks count]; i++) {
            printf("\033[0;32m%s\033[0m\n", [successfulCracks[i] UTF8String]);
        }
    }
    
    if (failedCracks && failedCracks.count > 0)
    {
        MSG(COMPLETE_APPS_FAILED);
        
        for (int i = 0; i < [failedCracks count]; i++) {
            printf("\033[0;32m%s\033[0m\n", [failedCracks[i] UTF8String]);
        }
    }
    
    MSG(COMPLETE_TOTAL, (int)[successfulCracks count], (int)[failedCracks count]);
}

void cmd_version()
{
    printf("%s %s (%s)\n", CLUTCH_TITLE, CLUTCH_VERSION, CLUTCH_RELEASE);
    printf("---------------------------------\n");
}

void cmd_help()
{
    cmd_version();
    printf("Clutch Help\n");
    printf("----------------------\n");
    printf("-c          Runs configuration utility\n");
    printf("-a          Cracks all applications\n");
    printf("-u          Cracks updated applications\n");
    printf("-f          Clears cache\n");
    printf("-v          Shows version\n");
    printf("\n");
}

void cmd_list_applications(NSArray *applications)
{
    NSEnumerator *e = [applications objectEnumerator];
    CAApplication* app;
    
    int cindex = 1;
    
    if ([[Prefs sharedInstance] numberBasedMenu])
    {
        printf("\n");
    }
    
    NSString* comparedValue;
    
    while (app = [e nextObject])
    {
        comparedValue = [app->_info objectForKey:get_compare_with()];
        
        if ([[Prefs sharedInstance] numberBasedMenu])
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
    NSEnumerator *e = [applications objectEnumerator];
    
    MSG(CLUTCH_CRACKING_ALL);
    
    CAApplication* app;
    
    NSString *ipapath;
    
    while (app = [e nextObject])
    {
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
    }
    
    return 0;
}

int cmd_crack_app(CAApplication *app, int yopa_enabled)
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

        MSG(COMPLETE_ELAPSED_TIME, dif);
        
        return 0;
    }
    else
    {
        [failedCracks addObject:app.applicationName];
        
        printf("Failed.\n");
        
        [cracker release];
        
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
            MSG(CLUTCH_DEV_CHECK_UPDATE);
            
            if (!check_version())
            {
                // Clutch needs updating.
                return retVal;
            }
        }
        
        gettimeofday(&start, NULL);
        
        [[Localization sharedInstance] checkCache];
        
        NSMutableArray *successfulCracks = [[NSMutableArray alloc] init];
        NSMutableArray *failedCracks = [[NSMutableArray alloc] init];
        
        cmd_version();
        
        NSArray *arguments = [[NSProcessInfo processInfo] arguments];
        NSArray *applist = [[CAApplicationsController sharedInstance] installedApps];
        
        if (applist == NULL)
        {
            MSG(CLUTCH_NO_APPLICATIONS);
        
            goto endMain;
        }
        
        for (int i = 0; i < arguments.count; i++)
        {
            NSString *arg = arguments[i];
            
            if (arguments.count == 1 && [arg isEqualToString:@"/usr/bin/Clutch"])
            {
                // User just typed `Clutch` list applications
                cmd_list_applications(applist);
                
                goto endMain;
            }
            
            if ([arg isEqualToString:@"-a"] || [arg isEqualToString:@"-all"])
            {
                retVal = cmd_crack_all(applist);
            }
            else if ([arg isEqualToString:@"-f"] || [arg isEqualToString:@"-flush"])
            {
                [[NSFileManager defaultManager] removeItemAtPath:@"/var/cache/clutch.plist" error:NULL];
                
                printf("Done.");
            }
            else if ([arg isEqualToString:@"-v"] || [arg isEqualToString:@"-version"])
            {
                cmd_version();
            }
            else if ([arg isEqualToString:@"-c"] || [arg isEqualToString:@"-C"] || [arg isEqualToString:@"-config"])
            {
                [[Prefs sharedInstance] setupConfig];
            }
            else if ([arg isEqualToString:@"-i"] || [arg isEqualToString:@"-install"])
            {
                NSString *ipa = [NSString stringWithUTF8String:argv[2]];
                NSString *binary = [NSString stringWithUTF8String:argv[3]];
                NSString *outbinary = [NSString stringWithUTF8String:argv[4]];
                
                Install *install = [[Install alloc] initWithIPA:ipa withBinary:binary];
                [install installIPA];
                [install crackWithOutBinary:outbinary];
                [install release];
            }
            else if ([arg isEqualToString:@"-h"] || [arg isEqualToString:@"-help"])
            {
                cmd_help();
            }
            else
            {
                BOOL numberMenu = [[Prefs sharedInstance] numberBasedMenu];
                
                CAApplication *app;
                
                int yopa_enabled = 0;
                
                for (int i = 1; i < arguments.count; i++)
                {
                    if ([arguments[i] isEqualToString:@"--yopa"])
                    {
                        MSG(CLUTCH_ENABLED_YOPA);
                        yopa_enabled = 1;
                    }
                    
                    NSEnumerator *e = [applist objectEnumerator];

                    int cindex = 0;
                    NSString* comparedValue;
                    
                    while (app = [e nextObject])
                    {
                        cindex++;
                        
                        comparedValue = [app->_info objectForKey:get_compare_with()];
                        
                        if (!numberMenu && ([comparedValue caseInsensitiveCompare:[NSString stringWithCString:argv[i] encoding:NSASCIIStringEncoding]] == NSOrderedSame))
                        {
                        
                            int success = cmd_crack_app(app, yopa_enabled);
                            
                            if (success == 1)
                            {
                                // Shit went wrong
                            }
                            else
                            {
                                // Shit went right
                            }
                            
                            break;
                            
                        } else {
                            if (numberMenu && (0 == strcmp([[NSString stringWithFormat:@"%d", cindex] UTF8String], argv[i])))
                            {
                                int success = cmd_crack_app(app, yopa_enabled);
                                
                                if (success == 1)
                                {
                                    // Shit went wrong
                                }
                            }
                        }
                    }
                }
            }
        }
    
        goto endMain;
        
endMain:
        [successfulCracks release];
        [failedCracks release];
        return retVal;
    }
}


