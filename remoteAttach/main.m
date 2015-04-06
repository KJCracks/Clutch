//
//  main.m
//  Clutch - remoteAttach
//
//  Created by ttwj on 06.04.15.
//
//

#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import "CPDistributedMessanging.h"

@interface Observer : NSObject
{
    CPDistributedMessagingCenter *center;
}
@end


@implementation Observer

- (id)init
{
    if ((self = [super init]))
    {
        center = [CPDistributedMessagingCenter centerNamed:@"com.clutch.remoteAttach"];
        [center runServerOnCurrentThread];
        [center registerForMessageName:@"loadFramework" target:self selector:@selector(loadFramework:userInfo:)];
        [center sendMessageAndReceiveReplyName:@"hello" userInfo:nil];
        //[center registerForMessageName:@"doneLoadingFrameworks" target:self selector:@selector(doneLoadingFrameworks:userInfo:)];
    }
    return self;
}

-(NSDictionary*)loadFramework:(NSString *)name userInfo:(NSDictionary *)userInfo {
    NSString* framework = (NSString*)userInfo[@"location"];
    void *dylib = dlopen(framework.UTF8String, RTLD_LAZY);
    if (!dylib) {
        fprintf(stderr, "Cannot load framework: %s\n", dlerror());
        exit(EXIT_FAILURE);
    }
    
    int32_t imageCount = _dyld_image_count();
    uint32_t dyldIndex = -1;
    
    for (uint32_t idx = 0; idx < imageCount; idx++) {
        NSString *dyldPath = [NSString stringWithUTF8String:_dyld_get_image_name(idx)];
        NSLog(@"wow %@", dyldPath);
        if ([framework.lastPathComponent isEqualToString:dyldPath.lastPathComponent]) {
            dyldIndex = idx;
            break;
        }
    }
    NSMutableDictionary* result = [NSMutableDictionary new];
    result[@"vmaddr_slide"] = [[NSNumber alloc] initWithLong:_dyld_get_image_vmaddr_slide(dyldIndex)];
    //[center sendMessageName:@"loadFramework" userInfo:result];
    return result;
}

@end

int main (int argc, const char * argv[])
{

    // insert code here..
    printf("Hello, World! #welcome #to #remoteattach #son\n");
    Observer* observer = [[Observer alloc] init];
    
	return 0;
}

