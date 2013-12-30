//
//  Packager.m
//  Clutch
//
//  Created by DilDog on 12/22/13.
//
//

#import "Packager.h"

@implementation Packager


- (id)init
{
    self = [super init];
    if (self)
    {
        _outputPath = NULL;
    }
    return self;
}

-(void)dealloc
{
    if(_outputPath)
    {
        [_outputPath release];
    }
    [super dealloc];
}


-(NSString *)getOutputPath
{
    return _outputPath;
}

-(BOOL)packFromSource:(NSString *)inputpath withOverlay:(NSString *)overlaypath
{
    return YES;
}


@end