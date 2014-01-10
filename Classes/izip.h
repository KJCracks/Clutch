#import "ZipArchive.h"
#import "Cracker.h"

void zip_original(ZipArchive *archiver, NSString *folder, NSString *binary, NSString* zip,int compressionLevel);
void zip(ZipArchive *archiver, NSString *folder, NSString* payloadPath, int compressionLevel);

@interface iZip : NSObject
{
    BOOL* zip_original;
    BOOL* zip_cracked;
    Cracker* _cracker;
    @public
    ZipArchive* _archiver;
}
- (instancetype)initWithCracker:(Cracker*) cracker;
- (void) zipOriginal:(NSOperation*)operation;
- (void) zipCracked;
- (void) zipOriginalOld:(NSOperation*) operation;

@end