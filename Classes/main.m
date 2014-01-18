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
 Introducing Clutch, the fastest and most advanced cracking utility for the iPhone, iPod Touch, and iPad.
 
 Created by dissident at Hackulo.us (<http://hackulo.us/>)
 Credit: Nighthawk, puy0, rwxr-xr-x, Flox, Flawless, FloydianSlip, Crash-X, MadHouse, Rastignac, aulter, icefire
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#import "CAApplicationsController.h"
#import "install.h"
#import "CABinary.h"
#import "Cracker.h"
#import "Packager.h"
#import <sys/time.h>

BOOL crack = FALSE;
BOOL readCompression;

int diff_ms(struct timeval t1, struct timeval t2)
{
    return (int)((((t1.tv_sec - t2.tv_sec) * 1000000) +
                  (t1.tv_usec - t2.tv_usec)) / 1000);
}

BOOL check_version() {
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://kjcracks.github.io/Clutch/current_build"] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    NSURLResponse* response = [[NSURLResponse alloc] init];
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    int build_version = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] intValue];
    if (build_version > CLUTCH_BUILD) {
        printf("Your current version of Clutch %u is outdated!\nPlease get the latest version %u!\n", CLUTCH_BUILD, build_version);
        return FALSE;
    } else {
        //printf("Your version of Clutch is up to date!\n");
        MSG(CLUTCH_DEV_UP_TO_DATE);
    }
    return TRUE;
}
static NSString* get_compare_with() {
    static NSString* compare;
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        if ([[[Prefs sharedInstance] objectForKey:@"ListWithDisplayName"] isEqualToString:@"DIRECTORY"]) {
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
int main(int argc, char *argv[]) {
    struct timeval start,end;
    gettimeofday(&start, NULL);
    [[Localization sharedInstance] checkCache];
    int retVal = 0;
    if (CLUTCH_DEV == 1) {
        MSG(CLUTCH_DEV_CHECK_UPDATE);
        if (!check_version()) {
            return retVal;
        }
    }
    //NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (getuid() != 0) {
        if ([Localization sharedInstance]->setuidPerformed) {
            //setuid to root needs chown:root, dumb users won't udnerstand
            printf("Localization cache obtained, please re-run Clutch\n");
            printf("已获取本地化缓存, 请重新运行\n");
            goto endMain;
        }
		printf("You must be root to use Clutch.\n");
		goto endMain;
	}
	
	// we need to import the configuration file
    
    NSMutableArray *successfulCracks = [[NSMutableArray alloc] init];
    NSMutableArray *failedCracks = [[NSMutableArray alloc] init];
    printf("Clutch %s%s\n", CLUTCH_VERSION, CLUTCH_RELEASE);
    
	if (argc < 2) {
        
		NSArray *applist = [[CAApplicationsController sharedInstance] installedApps];
		if (applist == NULL) {
			printf("There are no encrypted applications on this device.\n");
			goto endMain;
		}
		printf("usage: %s [flags] [application name] [...]\n", argv[0]);
		printf("Applications available: ");
		NSEnumerator *e = [applist objectEnumerator];
		CAApplication* app;
		int cindex = 1;
		
		if ([[Prefs sharedInstance] numberBasedMenu]) {
			printf("\n");
		}
		NSString* comparedValue;
		while (app = [e nextObject]) {
            comparedValue = [app->_info objectForKey:get_compare_with()];
			if ([[Prefs sharedInstance] numberBasedMenu]) {
				printf("%d) \033[1;3%dm%s\033[0m \n", cindex, 5 + ((cindex + 1) % 2), [comparedValue UTF8String]);
                cindex++;
			} else {
				printf("\033[1;3%dm%s\033[0m ", 5 + ((cindex + 1) % 2), [comparedValue UTF8String]);
                cindex++;
			}
            
		}
		
		printf("\n");
		
		goto endMain;
	}
	
	if (strncmp(argv[1], "-a", 3) == 0) {
		NSArray *applist = [[CAApplicationsController sharedInstance] installedApps];
		if (applist == NULL) {
			printf("There are no encrypted applications on this device.\n");
			goto endMain;
		}
		NSEnumerator *e = [applist objectEnumerator];
		printf("Cracking all encrypted applications on this device.\n");
		
		CAApplication* app;
		NSString *ipapath;
        
		while (app = [e nextObject]) {
			//printf("Cracking %s...\n", [app.applicationName UTF8String]);
            MSG(CRACKING_APPNAME, app.applicationName);
            
            Cracker *cracker = [[Cracker alloc] init];
            [cracker prepareFromInstalledApp:app];
            ipapath = [cracker generateIPAPath];
            
            if ([cracker execute]) {
                gettimeofday(&end, NULL);
                crack = TRUE;
				printf("\t%s\n", [ipapath UTF8String]);
                [successfulCracks addObject:app.applicationName];
            }
			else {
                [failedCracks addObject:app.applicationName];
				printf("Failed.\n");
			}
		}
	} else if (strncmp(argv[1], "-f", 2) == 0) {
		[[NSFileManager defaultManager] removeItemAtPath:@"/var/cache/clutch.plist" error:NULL];
		printf("Caches cleared.\n");
	} else if (strncmp(argv[1], "-v", 2) == 0) {
		printf("%s\n", CLUTCH_VERSION);
	} else if (strncmp(argv[1], "-b", 2) == 0) {
		printf("%d\n", CLUTCH_BUILD);
	} else if (strncmp(argv[1], "-C", 2) == 0) {
        [[Prefs sharedInstance] setupConfig];
        return 0;
    } else if (strncmp(argv[1], "-c", 2) == 0) {
        [[Prefs sharedInstance] setupConfig];
        return 0;
    } else if (strncmp(argv[1], "-i", 2) == 0) {
        NSString *ipa = [NSString stringWithUTF8String:argv[2]];
        printf("one \n");
        NSString *binary = [NSString stringWithUTF8String:argv[3]];
        printf("two \n");
        NSString *outbinary = [NSString stringWithUTF8String:argv[4]];
        printf("three \n");
        Install* install = [[Install alloc] initWithIPA:ipa withBinary:binary];
        [install installIPA];
        DebugLog(@"install ipa ok!");
        [install crackWithOutBinary:outbinary];
        
    }
    else if (strncmp(argv[1], "-h", 2) == 0) {
        goto help;
    }
    else {
        printf("%s\n", CLUTCH_VERSION);
		BOOL numberMenu = [[Prefs sharedInstance] numberBasedMenu];
		NSArray *applist = [[CAApplicationsController sharedInstance] installedApps];
        
		if (applist == NULL) {
			printf("There are no encrypted applications on this device.\n");
			goto endMain;
		}
    		
		NSString *ipapath;
		CAApplication* app;
		BOOL cracked = false, yopa_enabled = false;
		for (int i = 1; i<argc; i++) {
            if (!strcmp(argv[i], "--yopa")) {
                printf("YOPA is enabled.\n");
                yopa_enabled = true;
            }
			NSEnumerator *e = [applist objectEnumerator];
			int cindex = 0;
            NSString* comparedValue;
			while (app = [e nextObject]) {
				cindex++;
                comparedValue = [app->_info objectForKey:get_compare_with()];
				if (!numberMenu && ([comparedValue caseInsensitiveCompare:[NSString stringWithCString:argv[i] encoding:NSASCIIStringEncoding]] == NSOrderedSame)) {
                inCrackRoutine:
					cracked = TRUE;
					//printf("Cracking %s...\n", [app.applicationName UTF8String]);
                    MSG(CRACKING_APPNAME, app.applicationName);
                    
                    Cracker *cracker = [[Cracker alloc] init];
                    
                    [cracker prepareFromInstalledApp:app];
                    
                    [cracker yopaEnabled:yopa_enabled];
                    
                    ipapath = [cracker generateIPAPath];
                    
                    if ([cracker execute]) {
                        gettimeofday(&end, NULL);
                        crack = TRUE;
                        printf("\t%s\n", [ipapath UTF8String]);
                        [successfulCracks addObject:app.applicationName];
                    }
                    else {
                        [failedCracks addObject:app.applicationName];
                        printf("Failed.\n");
                    }
					break;
				} else {
					if (numberMenu && (0 == strcmp([[NSString stringWithFormat:@"%d", cindex] UTF8String], argv[i]))) {
						goto inCrackRoutine;
					}
				}
			}
			cracked = FALSE;
		}
	}
    
    if (crack) {
        int dif = diff_ms(end,start);
        //printf("\nelapsed time: %dms\n", dif);
        MSG(COMPLETE_ELAPSED_TIME, dif);
    }
    
    //printf("\nApplications Cracked: \n");
    MSG(COMPLETE_APPS_CRACKED);
    
    for (int i = 0; i < [successfulCracks count]; i++) {
        printf("\033[0;32m%s\033[0m\n", [successfulCracks[i] UTF8String]);
    }
    
    //printf("\nApplications that Failed:\n");
    MSG(COMPLETE_APPS_FAILED);
    
    for (int i = 0; i < [failedCracks count]; i++) {
        printf("\033[0;32m%s\033[0m\n", [failedCracks[i] UTF8String]);
    }
    
    //printf("\nTotal Success: \033[0;32m%lu\033[0m Total Failed: \033[0;33m%lu\033[0m\n\n", (unsigned long)[successfulCracks count], (unsigned long)[failedCracks count]);
    MSG(COMPLETE_TOTAL, (int)[successfulCracks count], (int)[failedCracks count]);
	
endMain:
	return retVal;
    //[pool release];
help:
    printf("%s\n", CLUTCH_VERSION);
    printf("Clutch Help\n");
    printf("---------------------------------\n");
    printf("-c          Runs configuration utility\n");
    printf("-a          Cracks all applications\n");
    printf("-u          Cracks updated applications\n");
    printf("-f          Clears cache\n");
    printf("-v          Shows version\n");
    printf("\n");
    
    //[pool release];
}


