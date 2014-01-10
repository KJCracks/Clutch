//
//  Cracker.h
//  Clutch
//
//  Created by DilDog on 12/22/13.
//
//

#import <Foundation/Foundation.h>
#import "CABinary.h"
#import "CAApplication.h"

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
    CAApplication *_app;
    NSString *_workingDir;
    NSString *_ipapath;
}

-(id)init;
-(BOOL)createFullCopyOfContents:(NSString *)outdir withAppBaseDir:(NSString *)appdir;
-(BOOL)createPartialCopy:(NSString *)outdir withApplicationDir:(NSString *)appdir withMainExecutable:(NSString *)mainexe;
-(BOOL)prepareFromInstalledApp:(CAApplication*)app;
-(BOOL)prepareFromSpecificExecutable:(NSString *)exepath returnDescription:(NSMutableString *)description;
-(NSString *)getAppDescription;
-(NSString *)getOutputFolder;
-(BOOL)execute;
-(NSString*) generateIPAPath;

@end