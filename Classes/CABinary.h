//
//  CABinary.h
//  CrackAddict
//
//  Created by Zorro on 13/11/13.
//  Copyright (c) 2013 AppAddict. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "out.h"
#import "Prefs.h"

#include <mach-o/fat.h>
#include <mach-o/loader.h>
#include <mach-o/dyld.h>
#include <mach-o/arch.h>


@interface CABinary : NSObject
{
    @public
       BOOL overdriveEnabled;
}

- (id)initWithBinary:(NSString *)path;
- (BOOL)crackBinaryToFile:(NSString *)path error:(NSError **)error;

@end
