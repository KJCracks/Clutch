//
//  Cracker.h
//  Clutch
//
//  Created by DilDog on 12/22/13.
//
//

#import <Foundation/Foundation.h>
#import "CABinary.h"
#import "Application.h"

@interface Cracker : NSObject
{
    NSString* _tempPath;
    @public
    NSString *_appDescription;
    NSString *_finaldir;
    NSString *_baselinedir;
    NSString *_tempBinaryPath;
    NSString *_binaryPath;
    CABinary *_binary;
    Application *_app;
    NSString *_workingDir;
    NSString *_ipapath;
    NSString *_yopaPath;
    BOOL* _yopaEnabled;
}

-(id)init;
-(BOOL)prepareFromInstalledApp:(Application*)app;
-(BOOL)execute;
-(NSString*) generateIPAPath;
-(void)yopaEnabled:(BOOL) dunno;

@end