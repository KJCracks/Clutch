//
//  Packager.h
//  Clutch
//
//  Created by DilDog on 12/22/13.
//
//

#import <Foundation/Foundation.h>

@interface Packager : NSObject
{
    NSString *_outputPath;
}


-(id)init;
-(void)dealloc;
-(NSString *)getOutputPath;
-(BOOL)packFromSource:(NSString *)inputpath withOverlay:(NSString *)overlaypath;

@end