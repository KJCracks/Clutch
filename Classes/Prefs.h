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

+ (Prefs *) sharedInstance;
- (void)setBool:(BOOL)value forKey:(NSString *)defaultName;
- (void)setObject:(id)value forKey:(NSString *)defaultName;
- (BOOL)boolForKey:(NSString *)defaultName;
- (id)objectForKey:(NSString *)defaultName;

@end