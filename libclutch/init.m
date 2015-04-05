//
//  main.m
//  Clutch
//
//  Created by Anton Titkov on 04.04.15.
//
//

#import "libclutch.h"
#import <Foundation/Foundation.h>
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
       center = [CPDistributedMessagingCenter centerNamed:@"com.clutch.libClutch"];
        [center runServerOnCurrentThread];
        [center registerForMessageName:@"loadFramework" target:self selector:@selector(loadFramework:userInfo:)];
        [center registerForMessageName:@"doneLoadingFrameworks" target:self selector:@selector(doneLoadingFrameworks:userInfo:)];
    }
    return self;
}

-(void)loadFramework:(NSString *)name userInfo:(NSDictionary *)userInfo {
    void *dylib = dlopen(((NSString*)userInfo[@"location"]).UTF8String, RTLD_LAZY);
    if (!dylib) {
        fprintf(stderr, "Cannot load framework: %s\n", dlerror());
        exit(EXIT_FAILURE);
    }
}

-(void)doneLoadingFrameworks:(NSString *)name userInfo:(NSDictionary *)userInfo {
    unsigned int count = _dyld_image_count();
    	unsigned int i;
    NSMutableDictionary* addresses = [NSMutableDictionary new];
    for (i = 0; i < count; i++) {
        addresses[[NSString stringWithUTF8String:_dyld_get_image_name(i)]] = [[NSNumber alloc] initWithUnsignedInt:_dyld_get_image_vmaddr_slide(i)];
    }
    [center sendMessageName:@"frameworkList" userInfo:addresses];
}
@end

__attribute__((constructor))
void clutchInit(int argc, const char **argv, const char **envp, const char **apple, struct ProgramVars *pvars)
{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    
    NSLog(@"%s\n",[NSString stringWithFormat:@"OMFG WE ARE HERE %@ %@",processInfo.environment,processInfo.arguments].UTF8String);
    
    Observer* observer = [[Observer alloc] init];
   
    //[center registerForMessageName:@"dlopen" target:<#(id)#> selector:<#(SEL)#>]
    //_dyld_get_image_header_containing_address(;)
    //_dyld_register_func_for_add_image(&image_added);
}

/*static void image_added(const struct mach_header *mh, intptr_t slide) {
    Dl_info image_info;
    struct encryption_info_command* eic;
    int result = dladdr(mh, &image_info);
    
    NSLog(@"image_added %s\n",image_info.dli_fname);
    
    NSNumber* address = [NSNumber numberWithUnsignedInteger:image_info.dli_saddr];
    
    struct load_command* lc;
    
    if (mh->magic == MH_MAGIC_64) {
        		lc = (struct load_command *)((unsigned char *)mh + sizeof(struct mach_header_64));
    } else {
        		lc = (struct load_command *)((unsigned char *)mh + sizeof(struct mach_header));
    }
    
    for (int i=0; i<mh->ncmds; i++) {
        if (lc->cmd == LC_ENCRYPTION_INFO || lc->cmd == LC_ENCRYPTION_INFO_64) {
            eic = (struct encryption_info_command *)lc;
    
            NSNumber* cryptid_address = [NSNumber numberWithUnsignedInteger:(uint32_t)(mh) + eic->cryptoff];
            
            NSNumber* cryptsize = [NSNumber numberWithUnsignedInteger:eic->cryptsize];
            NSNumber* cryptoff = [NSNumber numberWithUnsignedInteger:eic->cryptoff];
        }
    }
    //image_info
    //exit(0);
    //dumptofile(image_info.dli_fname, mh);
}

void update() {
    
    
}*/