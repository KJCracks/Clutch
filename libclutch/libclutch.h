//
//  libclutch.h
//  clutch
//
//  Created by Anton Titkov on 04.04.15.
//  Copyright (c) 2015 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <fcntl.h>
#import <dlfcn.h>
#import <mach-o/fat.h>
#import <mach-o/loader.h>
#import <mach-o/dyld.h>

struct ProgramVars {
    struct mach_header*	mh;
    int*		NXArgcPtr;
    const char***	NXArgvPtr;
    const char***	environPtr;
    const char**	__prognamePtr;
};

#define swap32(value) (((value & 0xFF000000) >> 24) | ((value & 0x00FF0000) >> 8) | ((value & 0x0000FF00) << 8) | ((value & 0x000000FF) << 24) )

__attribute__((constructor)) void clutchInit(int argc, const char **argv, const char **envp, const char **apple, struct ProgramVars *pvars);
static void image_added(const struct mach_header *mh, intptr_t slide);
