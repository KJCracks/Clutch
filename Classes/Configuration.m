#import "Configuration.h"
#include <stdio.h>
#include <stdlib.h>

static NSMutableDictionary *configurationDictionary = nil;
static NSString *configPath = nil;

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
    NSString* support;
    char read[40];
    for (NSString* key in configurationDictionary) {
        
        if ([key isEqualToString:@"MetadataPurchaseDate"]) {
            continue;
        }
        
        id value = [configurationDictionary objectForKey:key];
        support = [help objectForKey:key];
        IFPrint([NSString stringWithFormat:@"%@\n - %@ (%@) ", key, support, value]);
        int nChars = 1000;
        nChars = scanf("%39s", read);
        while (nChars > 38) {
            IFPrint(@"error: too long, please try again\n");
            nChars = scanf("%39s", read);
        }
        NSString* input = [NSString stringWithUTF8String:read];
        if (nChars > 0) {
            IFPrint(@"Using default value..\n");
            [self setValue:key forKey:input];
        }
        
    }
    
}



void IFPrint (NSString *format, ...) {
    va_list args;
    va_start(args, format);
    
    fputs([[[[NSString alloc] initWithFormat:format arguments:args] autorelease] UTF8String], stdout);
    
    va_end(args);
}

@end
