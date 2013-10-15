/* This program is free software. It comes without any warranty, to
 * the extent permitted by applicable law. You can redistribute it
 * and/or modify it under the terms of the Do What The Fuck You Want
 * To Public License, Version 2, as published by Sam Hocevar. See
 * http://www.wtfpl.net/ for more details. */

/*
 Introducing Clutch, the fastest and most advanced cracking utility for the iPhone, iPod Touch, and iPad.
 
 Created by dissident at Hackulo.us (<http://hackulo.us/>)
 Credit: Nighthawk, puy0, rwxr-xr-x, Flox, Flawless, FloydianSlip, Crash-X, MadHouse, Rastignac, aulter, icefire
 */

#import "Configuration.h"
#import "applist.h"
#import "crack.h"
#import "install.h"
#import <unistd.h>

BOOL crack = FALSE;
BOOL readCompression;

int diff_ms(struct timeval t1, struct timeval t2)
{
    return (((t1.tv_sec - t2.tv_sec) * 1000000) +
            (t1.tv_usec - t2.tv_usec))/1000;
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
        printf("Your version of Clutch is up to date!\n");
    }
    return TRUE;
}

int main(int argc, char *argv[]) {
    compression_level = -1;
    struct timeval start,end;
    gettimeofday(&start, NULL);
    
    int retVal = 0;
    if (CLUTCH_DEV == 1) {
        printf("You're using a Clutch development build, checking for updates..\n");
        if (!check_version()) {
            return retVal;  
        }
    }
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (getuid() != 0) {
		printf("You must be root to use Clutch.\n");
		goto endMain;
	}
	
	// we need to import the configuration file
	[ClutchConfiguration configWithFile:@"/etc/clutch.conf"];
    
	if (argc < 2) {
        printf("%s\n", CLUTCH_VERSION);
		NSArray *applist = get_application_list(TRUE, FALSE);
		if (applist == NULL) {
			printf("There are no encrypted applications on this device.\n");
			goto endMain;
		}
		printf("usage: %s [flags] [application name] [...]\n", argv[0]);
		printf("Applications available: ");
		NSEnumerator *e = [applist objectEnumerator];
		NSDictionary *applicationDetails;
		NSString *compareWith;
		if ([(NSString *)[ClutchConfiguration getValue:@"ListWithDisplayName"] isEqualToString:@"YES"]) {
			compareWith = @"ApplicationDisplayName";
		} else if ([(NSString *)[ClutchConfiguration getValue:@"ListWithDisplayName"] isEqualToString:@"DIRECTORY"]) {
			compareWith = @"RealUniqueID";
		} else {
			compareWith = @"ApplicationName";
		}
        
		int cindex = 1;
		
		BOOL numberMenu = [(NSString *)[ClutchConfiguration getValue:@"NumberBasedMenu"] isEqualToString:@"YES"];
		if (numberMenu) {
			printf("\n");
		}
		
		while (applicationDetails = [e nextObject]) {
			if (numberMenu) {
				printf("%d) \033[1;3%dm%s\033[0m \n", cindex, 5 + ((cindex++) % 2), [[applicationDetails objectForKey:compareWith] UTF8String]);
			} else {
				printf("\033[1;3%dm%s\033[0m ", 5 + ((cindex++) % 2), [[applicationDetails objectForKey:compareWith] UTF8String]);
			}
        
		}
		
		printf("\n");
		
		goto endMain;
	}
	
	if (strncmp(argv[1], "-a", 3) == 0) {
		NSArray *applist = get_application_list(FALSE, FALSE);
		if (applist == NULL) {
			printf("There are no encrypted applications on this device.\n");
			goto endMain;
		}
		NSEnumerator *e = [applist objectEnumerator];
		printf("Cracking all encrypted applications on this device.\n");
		
		NSDictionary *applicationDetails;
		NSString *ipapath;
		
		while (applicationDetails = [e nextObject]) {
			printf("Cracking %s...\n", [[applicationDetails objectForKey:@"ApplicationName"] UTF8String]);
			ipapath = crack_application([applicationDetails objectForKey:@"ApplicationDirectory"], [applicationDetails objectForKey:@"ApplicationBasename"], [applicationDetails objectForKey:@"ApplicationVersion"]);
			if (ipapath == nil) {
				printf("Failed.\n");
			} else {
                gettimeofday(&end, NULL);
                crack = TRUE;
				printf("\t%s\n", [ipapath UTF8String]);
			}
		}
	} else if (strncmp(argv[1], "-u", 2) == 0) {
        NSArray *applist = get_application_list(FALSE, TRUE);
        if (applist == NULL) {
            printf("There are no new applications on this device that aren't cracked.\n");
            goto endMain;
        }
        NSEnumerator *e = [applist objectEnumerator];
        printf("Cracking all updated applications on this device.\n");
        
        NSDictionary *applicationDetails;
        NSString *ipapath;
        
        while (applicationDetails = [e nextObject]) {
            printf("Cracking %s...\n", [[applicationDetails objectForKey:@"ApplicationName"] UTF8String]);
            ipapath = crack_application([applicationDetails objectForKey:@"ApplicationDirectory"], [applicationDetails objectForKey:@"ApplicationBasename"], [applicationDetails objectForKey:@"ApplicationVersion"]);
            if (ipapath == nil) {
                printf("Failed.\n");
            } else {
                gettimeofday(&end, NULL);
                crack = TRUE;
                printf("\t%s\n", [ipapath UTF8String]);
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
        [ClutchConfiguration setupConfig];
    } else if (strncmp(argv[1], "-c", 2) == 0) {
        [ClutchConfiguration setupConfig];
    }
    else if (strncmp(argv[1], "-i", 2) == 0) {
        NSString *ipa = [NSString stringWithUTF8String:argv[2]];
        printf("one \n");
        NSString *binary = [NSString stringWithUTF8String:argv[3]];
        printf("two \n");
        NSString *outbinary = [NSString stringWithUTF8String:argv[4]];
        printf("three \n");
        install_and_crack(ipa, binary, outbinary);

        //printf("location %s\n", [location UTF8String]);
        
    }
    else if (strncmp(argv[1], "-z", 2) == 0) {
        printf("Using native zipping! (may be unstable)\n\n");
        new_zip = 1;
    } else if (strncmp(argv[1], "-h", 2) == 0) {
        goto help;
    }
    else {
        printf("%s\n", CLUTCH_VERSION);
		BOOL numberMenu = [(NSString *)[ClutchConfiguration getValue:@"NumberBasedMenu"] isEqualToString:@"YES"];
		NSArray *applist;
		if (numberMenu)
			applist = get_application_list(TRUE, FALSE);
		else
			applist = get_application_list(FALSE, FALSE);
        
		if (applist == NULL) {
			printf("There are no encrypted applications on this device.\n");
			goto endMain;
		}
		NSString *compareWith;
		
		if ([(NSString *)[ClutchConfiguration getValue:@"ListWithDisplayName"] isEqualToString:@"YES"]) {
			compareWith = @"ApplicationDisplayName";
		} else if ([(NSString *)[ClutchConfiguration getValue:@"ListWithDisplayName"] isEqualToString:@"DIRECTORY"]) {
			compareWith = @"RealUniqueID";
		} else {
			compareWith = @"ApplicationName";
		}
		
		NSString *ipapath;
		NSDictionary *applicationDetails;
		BOOL cracked = FALSE;
		for (int i = 1; i<argc; i++) {
			NSEnumerator *e = [applist objectEnumerator];
			int cindex = 0;
			while (applicationDetails = [e nextObject]) {
				cindex++;
				if (!numberMenu && ([(NSString *)[applicationDetails objectForKey:compareWith] caseInsensitiveCompare:[NSString stringWithCString:argv[i] encoding:NSASCIIStringEncoding]] == NSOrderedSame)) {
                inCrackRoutine:
					cracked = TRUE;
					printf("Cracking %s...\n", [[applicationDetails objectForKey:compareWith] UTF8String]);
					ipapath = crack_application([applicationDetails objectForKey:@"ApplicationDirectory"], [applicationDetails objectForKey:@"ApplicationBasename"], [applicationDetails objectForKey:@"ApplicationVersion"]);
					if (ipapath == nil) {
						printf("Failed.\n");
					} else {
                        gettimeofday(&end, NULL);
                        crack = TRUE;
						printf("\t%s\n", [ipapath UTF8String]);
					}
					break;
				} else {
					if (numberMenu && (0 == strcmp([[NSString stringWithFormat:@"%d", cindex] UTF8String], argv[i]))) {
						goto inCrackRoutine;
					}
				}
			}
			if (!cracked) {
                if (!strcmp(argv[i], "--overdrive")) {
                    printf("Overdrive is enabled.\n");
                    overdrive_enabled = 1;
                }
                /*if (readCompression) {
                    compression_level = atoi(argv[i]);
                    printf("compression level: %u\n", compression_level);
                    readCompression = FALSE;
                }
                else if (!readCompression && (!strcmp(argv[i], "-c"))) {
                    readCompression = TRUE;
                }*/
                else {
                    printf("error: Unrecognized application \"%s\"\n", argv[i]);
                }
			}
			cracked = FALSE;
		}
	}
    
    if (crack) {
        int dif = diff_ms(end,start);
        printf("\nelapsed time: %dms\n", dif);
    }
	
endMain:
	return retVal;
    [pool release];
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
    
    [pool release];
}



