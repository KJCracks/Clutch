#import "Configuration.h"
#include <stdio.h>
#include <stdlib.h>

static NSMutableDictionary *configurationDictionary = nil;
static NSString *configPath = nil;

#define MAX_NAME_SZ 256

@implementation ClutchConfiguration

+ (id) getValue:(NSString *)key {
	return [configurationDictionary objectForKey:key];
}

+ (void) setValueTemp:(id)value forKey:(NSString *)key {
	[configurationDictionary setValue:value forKey:key];
}
+ (BOOL) setValue:(id)value forKey:(NSString *)key {
	[configurationDictionary setValue:value forKey:key];
	[configurationDictionary writeToFile:configPath atomically:YES];
	return YES;
}

+ (BOOL) configWithFile:(NSString *)filename {
	configurationDictionary = [NSMutableDictionary dictionaryWithContentsOfFile:filename];
	configPath = filename;
	return TRUE;
}
+ (void) setupConfig {
    printf("Downloading config files..\n");
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://kjcracks.github.io/Clutch/support.plist"] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    NSURLResponse* response = [[NSURLResponse alloc] init];
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    NSError * error = nil;
    
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/clutch/"]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/lib/clutch"
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
    }
    if (error != nil) {
        IFPrint(@"error creating directory: %@", error);
        return;
       
    }
    [data writeToFile:@"/var/lib/clutch/support.plist" atomically:YES];
    
    printf("Clutch configuration\n===============\n");
    
    NSDictionary* supportDictionary = [NSDictionary dictionaryWithContentsOfFile:@"/var/lib/clutch/support.plist"];
    NSMutableDictionary* tempDict = [NSMutableDictionary dictionaryWithDictionary:configurationDictionary];
    NSString* support, *defaultValue;
    char *read;
    if (read == NULL) {
        printf ("No memory\n");
        return;
    }

    for (NSString* key in supportDictionary) {
        
        NSDictionary* supportEntry = [supportDictionary objectForKey:key];
        if ([[supportEntry objectForKey:@"enabled"] isEqualToString:@"NO"]) {
            IFPrint(@"Not enabled entry %@\n", key);
            continue;
        }
        support = [supportEntry objectForKey:@"support"];
        defaultValue = [configurationDictionary objectForKey:key];
        if (defaultValue == nil) {
            defaultValue = [supportEntry objectForKey:@"default"];
        }
        
        IFPrint([NSString stringWithFormat:@"%@\n - %@ (%@) ", key, support, defaultValue]);
        read = malloc (MAX_NAME_SZ);
        fgets(read, MAX_NAME_SZ, stdin);
        read[strlen(read) - 1] = '\0';
        NSString* input = [NSString stringWithUTF8String:read];
        //NSLog(@"input omg %@", input);
        //NSLog(@"value omg %@,", defaultValue);
        if (read[0] != '\0') {
            if ([[defaultValue lowercaseString] hasPrefix:@"y"] || [[defaultValue lowercaseString] hasPrefix:@"n"]) {
                if ([[input lowercaseString] hasPrefix:@"y"]) {
                    [tempDict setValue:@"YES" forKey:key];
                    free(read);
                    continue;
                }
                else if ([[input lowercaseString] hasPrefix:@"n"]) {
                    [tempDict setValue:@"NO" forKey:key];
                    free(read);
                    continue;
                }
                
                else {
                    IFPrint(@"error: invalid input\n");
                    return;
                }
            }
            NSLog(@"input: %@, %@", key, input);
            [tempDict setValue:input forKey:key];
        }
        else {
            IFPrint(@"Using default value..\n");
        }
        free(read);
    }
    configurationDictionary = tempDict;
    [configurationDictionary writeToFile:configPath atomically:YES];
}

NSString* generateIPAPath(NSString* displayName, NSString* version, NSString* minOS) {
    NSString* ipapath = [configurationDictionary objectForKey:@"FileRegex"];
    NSString* crackername = [configurationDictionary objectForKey:@"CrackerName"];
    ipapath = [ipapath stringByReplacingOccurrencesOfString:@"$appname" withString:displayName];
    ipapath = [ipapath stringByReplacingOccurrencesOfString:@"$appversion" withString:version];
    
    
    displayName = [displayName stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
  //  NSString* ipapath = [NSString stringWithFormat:@"/var/root/Documents/Cracked/%@-v%@-%@%@-(%@).ipa", displayName , version, crackerName, addendum, [NSString stringWithUTF8String:CLUTCH_VERSION]];
    return ipapath;
}

void IFPrint (NSString *format, ...) {
    va_list args;
    va_start(args, format);
    
    fputs([[[[NSString alloc] initWithFormat:format arguments:args] autorelease] UTF8String], stdout);
    
    va_end(args);
}

@end
