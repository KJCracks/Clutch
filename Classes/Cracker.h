//
//  Cracker.h
//  Clutch
//
//  Created by DilDog on 12/22/13.
//
//

#import <Foundation/Foundation.h>
#import "Binary.h"
#import "Application.h"

@interface Cracker : NSObject
{
    @public
    NSString* _tempPath;
    NSString *_appDescription;
    NSString *_finaldir;
    NSString *_baselinedir;
    NSString *_tempBinaryPath;
    NSString *_binaryPath;
    Binary *_binary;
    Application *_app;
    NSString *_workingDir;
    NSString *_ipapath;
}

-(id)init;
-(BOOL)prepareFromInstalledApp:(Application*)app;
-(BOOL)execute;
-(NSString*) generateIPAPath;

@end