//
//  main.m
//  Clutch
//
//  Created by Anton Titkov on 04.04.15.
//
//

#import "libclutch.h"

__attribute__((constructor))
void clutchInit(int argc, const char **argv, const char **envp, const char **apple, struct ProgramVars *pvars)
{
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    
    printf("%s\n",[NSString stringWithFormat:@"OMFG WE ARE HERE %@ %@",processInfo.environment,processInfo.arguments].UTF8String);
    
    _dyld_register_func_for_add_image(&image_added);
}

static void image_added(const struct mach_header *mh, intptr_t slide) {
    Dl_info image_info;
    int result = dladdr(mh, &image_info);
    
    printf("image_added %s\n",image_info.dli_fname);
    
    exit(0);
    //dumptofile(image_info.dli_fname, mh);
}