//
//  Prefs.h
//  CrackAddict
//
//  Created by Zorro on 4/7/13.
//  Copyright (c) 2013 Zorro. All rights reserved.
//

#import <Foundation/Foundation.h>

#define prefsPath @"/etc/clutch.conf"

@interface Prefs : NSObject
{
    NSMutableDictionary* _dict;
}

+ (Prefs *) sharedInstance;

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;
- (void)setObject:(id)value forKey:(NSString *)defaultName;
- (BOOL)boolForKey:(NSString *)defaultName;
- (id)objectForKey:(NSString *)defaultName;
- (void) setupConfig;
- (NSString*) crackerName;
- (BOOL) removeMetadata;
- (int) compressionLevel;
- (BOOL) listWithDisplayName;
- (NSString*) metadataPurchaseDate;
- (BOOL) useOverdrive;
- (BOOL) numberBasedMenu;
- (BOOL) addMinOS;
- (NSString*) metadataEmail;
- (NSString*) ipaDirectory;
- (BOOL) useNativeZip;
@end