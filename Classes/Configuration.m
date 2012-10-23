#import "Configuration.h"

static NSMutableDictionary *configurationDictionary = nil;
static NSString *configPath = nil;

@implementation ClutchConfiguration

+ (id) getValue:(NSString *)key {
	return [configurationDictionary objectForKey:key];
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

@end
