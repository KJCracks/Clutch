//
//  API.m
//  Clutch
//
//

#import "API.h"
#import "CAApplication.h"
#import "out.h"

#define sourcePath @"/tmp/clutch.source"

void run_getenv (const char * name)
{
    char * value;
    
    value = getenv (name);
    if (! value) {
        printf ("'%s' is not set.\n", name);
    }
    else {
        printf ("%s = %s\n", name, value);
    }
}
@implementation API

- (id)initWithApp:(CAApplication*) app
{
    self = [super init];
    if (self)
    {
        _dict = [[NSMutableDictionary alloc] initWithDictionary:app->_info];
    }
    return self;
}

-(void)setEnvironmentArgs {
    [_dict removeObjectForKey:@"ApplicationSINF"];
    NSString* source = @"";
    for (NSString* key in _dict) {
        NSString* line = [NSString stringWithFormat:@"\n%@=\"%@\"", key, [_dict objectForKey:key]];
        source = [source stringByAppendingString:line];
        //DebugLog(@"line %@", line);
    }
    [source writeToFile:sourcePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
-(void)setObject:(NSString*)obj forKey:(NSString*)key {
    [_dict setObject:obj forKey:key];
}

@end
