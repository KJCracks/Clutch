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
    printf("Clutch configuration\n===============\n");
    NSDictionary* help = [NSDictionary dictionaryWithContentsOfFile:@"/var/lib/clutch/support.plist"];
    NSMutableDictionary* tempDict = [NSMutableDictionary dictionaryWithDictionary:configurationDictionary];
    NSString* support;
    char *read;
    if (read == NULL) {
        printf ("No memory\n");
        return;
    }

    for (NSString* key in configurationDictionary) {
        
        if ([key isEqualToString:@"MetadataPurchaseDate"]) {
            continue;
        }
        
        id value = [configurationDictionary objectForKey:key];
        support = [help objectForKey:key];
        IFPrint([NSString stringWithFormat:@"%@\n - %@ (%@) ", key, support, value]);
        read = malloc (MAX_NAME_SZ);
        fgets(read, MAX_NAME_SZ, stdin);
        read[strlen(read) - 1] = '\0';
        NSString* input = [NSString stringWithUTF8String:read];
        NSLog(@"input omg %@", input);
        NSLog(@"value omg %@,", value);
        if (read[0] != '\0') {
            if ([[value lowercaseString] hasPrefix:@"y"] || [[value lowercaseString] hasPrefix:@"n"]) {
                if ([[input lowercaseString] hasPrefix:@"y"]) {
                    [tempDict setValue:key forKey:@"YES"];
                    continue;
                }
                else if ([[input lowercaseString] hasPrefix:@"n"]) {
                    [tempDict setValue:key forKey:@"NO"];
                    continue;
                }
                
                else {
                    IFPrint(@"error: invalid input\n");
                    return;
                }
            }
            NSLog(@"input: %@, %@", key, input);
            [tempDict setValue:key forKey:input];
        }
        else {
            IFPrint(@"Using default value..\n");
        }
        free(read);
    }
    configurationDictionary = tempDict;
    [configurationDictionary writeToFile:configPath atomically:YES];
}



void IFPrint (NSString *format, ...) {
    va_list args;
    va_start(args, format);
    
    fputs([[[[NSString alloc] initWithFormat:format arguments:args] autorelease] UTF8String], stdout);
    
    va_end(args);
}

@end
