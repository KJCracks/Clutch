//
//  Prefs.m
//  CrackAddict
//
//  Created by Zorro on 4/7/13.
//  Copyright (c) 2013 Zorro. All rights reserved.
//
#import "Prefs.h"

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

- (void)setBool:(BOOL)value forKey:(NSString *)defaultName{
    NSMutableDictionary *dict=[[NSMutableDictionary alloc]initWithContentsOfFile:prefsPath];
    if (dict==nil) {
        dict=[NSMutableDictionary new];
    }
    [dict setObject:[NSNumber numberWithBool:value] forKey:defaultName];
    [dict writeToFile:prefsPath atomically:YES];
}

- (void)setObject:(id)value forKey:(NSString *)defaultName{
    NSMutableDictionary *dict=[[NSMutableDictionary alloc]initWithContentsOfFile:prefsPath];
    if (dict==nil) {
        dict=[NSMutableDictionary new];
    }
    if (value==nil)
    {
        [dict removeObjectForKey:defaultName];
    }
    else
    {
        [dict setObject:value forKey:defaultName];
    }
    [dict writeToFile:prefsPath atomically:YES];
}

- (BOOL)boolForKey:(NSString *)defaultName{
    NSDictionary *dict=[NSDictionary dictionaryWithContentsOfFile:prefsPath];
    return [[dict objectForKey:defaultName]boolValue];
}

- (id)objectForKey:(NSString *)defaultName{
    NSDictionary *dict=[NSDictionary dictionaryWithContentsOfFile:prefsPath];
   return [dict objectForKey:defaultName];
}


@end