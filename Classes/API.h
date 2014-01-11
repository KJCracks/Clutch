//
//  API.h
//  Clutch
//
//
//

#import <Foundation/Foundation.h>
#import "CAApplication.h"

@interface API : NSObject
{
    NSMutableDictionary* _dict;
}

- (id)initWithApp:(CAApplication*) app;
-(void)setEnvironmentArgs;
-(void)setObject:(NSString*)obj forKey:(NSString*)key;

@end
