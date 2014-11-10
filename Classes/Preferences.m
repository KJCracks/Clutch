//
//  Preferences.m
//  CrackAddict
//
//  Created by Zorro on 4/7/13.
//  Copyright (c) 2013 Zorro. All rights reserved.
//

#import "Preferences.h"
#import "out.h"
#import "Localization.h"

#define MAX_NAME_SZ 256

static dispatch_once_t preferences_dispatch = 0;
NSString* preferences_location = prefsPath;

@implementation Preferences

+ (Preferences *) sharedInstance
{
    static Preferences *shared = nil;
    dispatch_once(&preferences_dispatch, ^{
        shared = [[Preferences alloc] init];
    });
    
    return shared;
}

+ (void)setConfigPath:(NSString*)path {
    preferences_dispatch = 0;
    preferences_location = path;
}

- (id)init
{
    self = [super init];
    
    if (self)
    {
        _dict = [[NSMutableDictionary alloc]initWithContentsOfFile:preferences_location];
        DEBUG(@"preferences_location: %@", preferences_location);
        DEBUG(@"%@", _dict);
        if (_dict==nil)
        {
            _dict=[NSMutableDictionary new];
        }
    }
    
    return self;
}

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName
{
    [_dict setObject:[NSNumber numberWithBool:value] forKey:defaultName];
    [_dict writeToFile:prefsPath atomically:YES];
}

- (void)tempSetObject:(id)value forKey:(NSString *)defaultName
{
    if (_dict == nil)
    {
        _dict = [NSMutableDictionary new];
    }
    
    if (value == nil)
    {
        [_dict removeObjectForKey:defaultName];
    }
    else
    {
        [_dict setObject:value forKey:defaultName];
        
    }
    //DEBUG(@"Preferences dictionary: %@", _dict);
    
}

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    [self tempSetObject:value forKey:defaultName];
    [_dict writeToFile:prefsPath atomically:YES];
}


- (BOOL)boolForKey:(NSString *)defaultName
{
    return [[_dict objectForKey:defaultName]boolValue];
}

- (id)objectForKey:(NSString *)defaultName
{
   return [_dict objectForKey:defaultName];
}

//quick n easy
- (BOOL) useOverdrive
{
    return [self boolForKey:@"UseOverdrive"];
}

-(NSString*) crackerName
{
    NSString *crackerName = [self objectForKey:@"CrackerName"];
    
    if (crackerName == nil)
    {
        crackerName = @"no-name-cracker";
    }
    
    return crackerName;
}
-(BOOL) removeMetadata
{
    return [self boolForKey:@"RemoveMetadata"];
}

-(int) compressionLevel
{
    return [[self objectForKey:@"CompressionLevel"] intValue];
}

-(BOOL) listWithDisplayName
{
    return [self boolForKey:@"ListWithDisplayName"];
}

- (BOOL) numberBasedMenu
{
    return [self boolForKey:@"NumberBasedMenu"];
}

- (BOOL) addMinOS
{
    return [self boolForKey:@"AddMinOS"];
}

- (BOOL) creditFile
{
    return [self boolForKey:@"CreditFile"];
}

- (BOOL) useNativeZip
{
    if (![self boolForKey:@"UseNativeZip"]) {
        if ((![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/zip"]) && (![[NSFileManager defaultManager] fileExistsAtPath:@"/bin/zip"])) {
            printf("\nwarning: could not find zip! using built-in zipping library\n\n");
            return true;
        }
        return false;
    }
    return [self boolForKey:@"UseNativeZip"];
}

- (NSString*) metadataEmail
{
    return [self objectForKey:@"MetadataEmail"];
}

-(NSString*) metadataPurchaseDate
{
    return [self objectForKey:@"MetadataPurchasDate"];
}

- (NSString*) ipaDirectory
{
    NSString *dir = [self objectForKey:@"IPADirectory"];
    if (dir == nil) {
        dir = @"/User/Documents/Cracked";
    }
    return dir;
}

- (void) setupConfig
{
    MSG(CONFIG_DOWNLOADING_FILES);
    NSString* support_plist;
    if ([[Localization sharedInstance] defaultLang] == zh) {
        support_plist = @"http://kjcracks.github.io/Clutch/support14.zh.plist";
    }
    else {
        support_plist = @"http://kjcracks.github.io/Clutch/support14.plist";
    }
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:support_plist] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];

    NSURLResponse* response = [[NSURLResponse alloc] init];
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
    NSError * error = nil;
    
    
    if(![[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/clutch/"])
    {
        [[NSFileManager defaultManager] createDirectoryAtPath:@"/var/lib/clutch"
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
    }
    
    if (error != nil)
    {
        DEBUG(@"Error creating directory: %@", error);
        return;
    }
    
    [data writeToFile:@"/var/lib/clutch/support.plist" atomically:YES];
    
    printf("Clutch configuration\n===============\n");
    
    NSDictionary* supportDictionary = [NSDictionary dictionaryWithContentsOfFile:@"/var/lib/clutch/support.plist"];
    NSMutableDictionary* tempDict = [NSMutableDictionary dictionaryWithDictionary:_dict];
    NSString* support, *defaultValue;
    
    char *read = "Mem?"; // probably a better way to do this
    if (!read)
    {
        printf ("No memory\n");
        
        return;
    }
    
    for (NSString* key in supportDictionary)
    {
        
        NSDictionary* supportEntry = [supportDictionary objectForKey:key];
        
        if ([[supportEntry objectForKey:@"enabled"] isEqualToString:@"NO"])
        {
            continue;
        }
        
        support = [supportEntry objectForKey:@"support"];
        defaultValue = [_dict objectForKey:key];
        
        if (defaultValue == nil)
        {
            defaultValue = [supportEntry objectForKey:@"default"];
        }
        
        NSPrint(@"%@\n - %@ (%@) ", key, support, defaultValue);
        
        read = malloc (MAX_NAME_SZ);
        fgets(read, MAX_NAME_SZ, stdin);
        read[strlen(read) - 1] = '\0';
        
        NSString* input = [NSString stringWithUTF8String:read];
       
        if (read[0] != '\0')
        {
            if ([[defaultValue lowercaseString] hasPrefix:@"y"] || [[defaultValue lowercaseString] hasPrefix:@"n"])
            {
                if ([[input lowercaseString] hasPrefix:@"y"])
                {
                    [tempDict setValue:@"YES" forKey:key];
                    free(read);
                    
                    continue;
                }
                else if ([[input lowercaseString] hasPrefix:@"n"])
                {
                    [tempDict setValue:@"NO" forKey:key];
                    free(read);
                    
                    continue;
                }
                else if ([[input lowercaseString] hasPrefix:@"directory"])
                {
                    [tempDict setValue:@"DIRECTORY" forKey:key];
                    free(read);
                    
                    continue;
                }
                else
                {
                    DEBUG(@"error: invalid input\n");
                    
                    return;
                }
            }
            
            [tempDict setValue:input forKey:key];
        }
        else
        {
            MSG(CONFIG_USING_DEFAULT);
        }
        
        free(read);
    }
    _dict = tempDict;
    [_dict writeToFile:prefsPath atomically:YES];
    
    MSG(CONFIG_SAVING);
}

@end