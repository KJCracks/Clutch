//
//  Prefs.m
//  CrackAddict
//
//  Created by Zorro on 4/7/13.
//  Copyright (c) 2013 Zorro. All rights reserved.
//
#import "Prefs.h"
#import "out.h"

#define MAX_NAME_SZ 256

@implementation Prefs

+ (Prefs *) sharedInstance
{
    static dispatch_once_t pred;
    static Prefs* shared = nil;
    dispatch_once(&pred, ^{
        shared = [Prefs new];
    });
    return shared;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        _dict = [[NSMutableDictionary alloc]initWithContentsOfFile:prefsPath];
        if (_dict==nil) {
            _dict=[NSMutableDictionary new];
        }
    }
    return self;
}

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName{
    [_dict setObject:[NSNumber numberWithBool:value] forKey:defaultName];
    [_dict writeToFile:prefsPath atomically:YES];
}

- (void)setObject:(id)value forKey:(NSString *)defaultName{
    if (_dict==nil) {
        _dict=[NSMutableDictionary new];
    }
    if (value==nil)
    {
        [_dict removeObjectForKey:defaultName];
    }
    else
    {
        [_dict setObject:value forKey:defaultName];
    }
    [_dict writeToFile:prefsPath atomically:YES];
}

- (BOOL)boolForKey:(NSString *)defaultName{
    return [[_dict objectForKey:defaultName]boolValue];
}

- (id)objectForKey:(NSString *)defaultName{
   return [_dict objectForKey:defaultName];
}


//quick n easy
- (BOOL) useOverdrive {
    return [self boolForKey:@"UseOverdrive"];
}
-(NSString*) crackerName {
    NSString *crackerName = [self objectForKey:@"CrackerName"];
    if (crackerName == nil) {
        crackerName = @"no-name-cracker";
    }
    return crackerName;
}
-(BOOL) removeMetadata {
    return [self boolForKey:@"RemoveMetadata"];
}
-(int) compressionLevel {
    return [[self objectForKey:@"CompressionLevel"] intValue];
}
-(BOOL) listWithDisplayName {
    return [self boolForKey:@"ListWithDisplayName"];
}
- (BOOL) numberBasedMenu {
    return [self boolForKey:@"NumberBasedMenu"];
}
- (BOOL) addMinOS {
    return [self boolForKey:@"AddMinOS"];
}
- (BOOL) creditFile {
    return [self boolForKey:@"CreditFile"];
}
- (BOOL) useNativeZip {
    return [self boolForKey:@"UseNativeZip"];
}
- (NSString*) metadataEmail {
    return [self objectForKey:@"MetadataEmail"];
}
-(NSString*) metadataPurchaseDate {
    return [self objectForKey:@"MetadataPurchasDate"];
}
- (NSString*) ipaDirectory {
    NSString *dir = [self objectForKey:@"IPADirectory"];
    if (dir == nil) {
        dir = @"/User/Documents/Cracked";
    }
    return dir;
}


- (void) setupConfig {
    printf("Downloading config files..\n");
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://kjcracks.github.io/Clutch/support14.plist"] cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
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
        DebugLog(@"error creating directory: %@", error);
        return;
        
    }
    [data writeToFile:@"/var/lib/clutch/support.plist" atomically:YES];
    
    printf("Clutch configuration\n===============\n");
    
    NSDictionary* supportDictionary = [NSDictionary dictionaryWithContentsOfFile:@"/var/lib/clutch/support.plist"];
    NSMutableDictionary* tempDict = [NSMutableDictionary dictionaryWithDictionary:_dict];
    NSString* support, *defaultValue;
    
    char *read = "Mem?"; // probably a better way to do this
    if (!read) {
        printf ("No memory\n");
        return;
    }
    
    for (NSString* key in supportDictionary) {
        
        //DEBUG("objectForKey: supportDictionary %s", [key UTF8String]);
        NSDictionary* supportEntry = [supportDictionary objectForKey:key];
        if ([[supportEntry objectForKey:@"enabled"] isEqualToString:@"NO"]) {
            //DebugLog(@"Not enabled entry %@\n", key);
            continue;
        }
        //DEBUG("objectForKey: supportEntry");
        support = [supportEntry objectForKey:@"support"];
        defaultValue = [_dict objectForKey:key];
        if (defaultValue == nil) {
            //DEBUG("objectForKey: defaultValue");
            defaultValue = [supportEntry objectForKey:@"default"];
        }
        
        NSPrint(@"%@\n - %@ (%@) ", key, support, defaultValue);
        read = malloc (MAX_NAME_SZ);
        fgets(read, MAX_NAME_SZ, stdin);
        read[strlen(read) - 1] = '\0';
        NSString* input = [NSString stringWithUTF8String:read];
        //DebugLog(@"input omg %@", input);
        //DebugLog(@"value omg %@,", defaultValue);
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
                else if ([[input lowercaseString] hasPrefix:@"directory"]) {
                    [tempDict setValue:@"DIRECTORY" forKey:key];
                    free(read);
                    continue;
                }
                
                else {
                    DebugLog(@"error: invalid input\n");
                    return;
                }
            }
            //DEBUG("input: %@, %@", key, input);
            [tempDict setValue:input forKey:key];
        }
        else {
           printf("Using default value..\n");
        }
        free(read);
    }
    _dict = tempDict;
    [_dict writeToFile:prefsPath atomically:YES];
    printf("\nSaving configuration settings..\n");
}



@end