/*
 Introducing Clutch, the fastest and most advanced cracking utility for the iPhone, iPod Touch, and iPad.
 
 Created by dissident at Hackulo.us (<http://hackulo.us/>)
 Credit: Nighthawk, puy0, rwxr-xr-x, Flox, Flawless, FloydianSlip, Crash-X, MadHouse, Rastignac, aulter, icefire
 */

#import "Configuration.h"
#import "applist.h"
#import "crack.h"

#import <unistd.h>
#import <QuartzCore/QuartzCore.h>

BOOL crack = FALSE;

int diff_ms(struct timeval t1, struct timeval t2)
{
    return (((t1.tv_sec - t2.tv_sec) * 1000000) +
            (t1.tv_usec - t2.tv_usec))/1000;
}

int main(int argc, char *argv[]) {
    struct timeval start,end;
    gettimeofday(&start, NULL);
    
    int retVal = 0;
    
    printf("%s\n", CLUTCH_VERSION);
    
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if (getuid() != 0) {
		printf("You must be root to use Clutch.\n");
        
		goto endMain;
	}
	
	[ClutchConfiguration configWithFile:@"/etc/clutch.conf"];
    
	if (argc < 2) {
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
        
		int cindex = 0;
		
		BOOL numberMenu = [(NSString *)[ClutchConfiguration getValue:@"NumberBasedMenu"] isEqualToString:@"YES"];
        
		if (numberMenu) {
			printf("\n");
		}
		
		while (applicationDetails = [e nextObject]) {
			if (numberMenu) {
				printf("%d ) \033[1;3%dm%s\033[0m ", cindex, 5 + ((cindex++) % 2), [[applicationDetails objectForKey:compareWith] UTF8String]);
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
        NSDictionary *applicationDetails;
		NSString *ipapath;
        
		printf("Cracking all encrypted applications on this device.\n");
		
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
        NSDictionary *applicationDetails;
        NSString *ipapath;
        
        printf("Cracking all updated applications on this device.\n");
        
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
	} else if (strncmp(argv[1], "-C", 2) == 0) {
        [ClutchConfiguration setupConfig];
    } else if (strncmp(argv[1], "-h", 2) == 0) {
        goto help;
    } else {
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
                else {
                    printf("error: Unrecognized application \"%s\"\n", argv[i]);
                }
			}
            
			cracked = FALSE;
		}
	}
    
    if (crack) {
        printf("\nelapsed time: %dms\n", diff_ms(end, start));
    }
	
endMain:
    [pool release];
	return retVal;
    
help:
    printf("Clutch Help\n");
    printf("---------------------------------\n");
    printf("-a          Cracks all applications\n");
    printf("-u          Cracks updated applications\n");
    printf("-f          Clears cache\n");
    printf("-v          Shows version\n");
    printf("\n");
    printf("--[no|fast|best]-compression       Set the compression level\n");
    
    [pool release];
}



