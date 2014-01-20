//
//  API.h
//  Clutch
//
//
//

#import <Foundation/Foundation.h>
#import "Application.h"

@interface API : NSObject
{
    NSMutableDictionary* _dict;
}

- (id)initWithApp:(Application*) app;
- (void)setEnvironmentArgs;
- (void)setObject:(NSString*)obj forKey:(NSString*)key;

@end
