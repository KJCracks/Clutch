/**
//  ZipArchive.m
//  
//
//  Created by aish on 08-9-11.
//  acsolu@gmail.com
//  Copyright 2008  Inc. All rights reserved.
//
*/

#import "ZipArchive.h"
#import "zlib.h"
#import "zconf.h"
#include "minizip/zip.h"
#include "minizip/unzip.h"


@interface NSFileManager(ZipArchive)
- (NSDictionary *)_attributesOfItemAtPath:(NSString *)path followingSymLinks:(BOOL)followingSymLinks error:(NSError **)error;
@end

@interface ZipArchive ()

-(void) OutputErrorMessage:(NSString*) msg;
-(BOOL) OverWrite:(NSString*) file;
-(NSDate*) Date1980;

@property (nonatomic,copy) NSString* password;
@end



@implementation ZipArchive
@synthesize delegate = _delegate;
@synthesize numFiles = _numFiles;
@synthesize password = _password;
@synthesize unzippedFiles = _unzippedFiles;
@synthesize progressBlock = _progressBlock;
@synthesize stringEncoding = _stringEncoding;

-(id) init
{
    return [self initWithFileManager:[NSFileManager defaultManager]];
}

-(id) initWithFileManager:(NSFileManager*) fileManager
{
	if( self=[super init] )
	{
		_zipFile = NULL;
        _fileManager = fileManager;
        self.stringEncoding = NSUTF8StringEncoding;
	}
	return self;
}

-(void) dealloc
{
    // close any open file operations
	[self CloseZipFile2];
    [self UnzipCloseFile];
    
    // release retained/copied properties.
    [_password release];
    [_delegate release];
    [_unzippedFiles release];
    
	[super dealloc];
}

/**
 * Create a new zip file at the specified path, ready for new files to be added.
 *
 * @param zipFile     the path of the zip file to create
 * @returns BOOL YES on success
 */

-(BOOL) CreateZipFile2:(NSString*) zipFile
{
	_zipFile = zipOpen( (const char*)[zipFile UTF8String], 0 );
	if( !_zipFile ) 
		return NO;
	return YES;
}

/**
 * Create a new zip file at the specified path, ready for new files to be added.
 *
 * @param zipFile     the path of the zip file to create
 * @param password    a password used to encrypt the zip file
 * @returns BOOL YES on success
 */

-(BOOL) CreateZipFile2:(NSString*) zipFile Password:(NSString*) password
{
	self.password = password;
	return [self CreateZipFile2:zipFile];
}

/**
 * add an existing file on disk to the zip archive, compressing it.
 *
 * @param file    the path to the file to compress
 * @param newname the name of the file in the zip archive, ie: path relative to the zip archive root.
 * @returns BOOL YES on success
 */

#define M_FRAGMENT_SIZE (1024*1024*15)

-(BOOL) addFileToZip:(NSString*) file newname:(NSString*) newname compressionLevel:(int) compressionLevel;
{
	if( !_zipFile )
		return NO;
    
    //	tm_zip filetime;
	time_t current;
	time( &current );
	
	zip_fileinfo zipInfo = {0};
    //	zipInfo.dosDate = (unsigned long) current;
	
	NSDictionary* attr = [[NSFileManager defaultManager] attributesOfItemAtPath:file error:nil];
	if( attr )
	{
		NSDate* fileDate = (NSDate*)[attr objectForKey:NSFileModificationDate];
		if( fileDate )
		{
			// some application does use dosDate, but tmz_date instead
            //	zipInfo.dosDate = [fileDate timeIntervalSinceDate:[self Date1980] ];
			NSCalendar* currCalendar = [NSCalendar currentCalendar];
			uint flags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit |
            NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit ;
			NSDateComponents* dc = [currCalendar components:flags fromDate:fileDate];
			zipInfo.tmz_date.tm_sec = (unsigned int)[dc second];
			zipInfo.tmz_date.tm_min = (unsigned int)[dc minute];
			zipInfo.tmz_date.tm_hour = (unsigned int)[dc hour];
			zipInfo.tmz_date.tm_mday = (unsigned int)[dc day];
			zipInfo.tmz_date.tm_mon = (unsigned int)[dc month] - 1;
			zipInfo.tmz_date.tm_year = (unsigned int)[dc year];
		}
	}
    
	int ret ;
	NSData* data = nil;
	if( [_password length] == 0 )
	{
		ret = zipOpenNewFileInZip( _zipFile,
								  (const char*) [newname UTF8String],
								  &zipInfo,
								  NULL,0,
								  NULL,0,
								  NULL,//comment
								  Z_DEFLATED,
								  compressionLevel );
	}
	else
	{
		FILE *f = fopen([file cStringUsingEncoding:NSUTF8StringEncoding], "r");
        fseek(f, 0, SEEK_END);
        long fLenght = ftell(f);
        void *fBuffer = malloc(fLenght);
        fread(fBuffer, 1, fLenght, f);
        fclose(f);
        data = [[NSData alloc] initWithBytesNoCopy:fBuffer length:fLenght];
		uLong crcValue = crc32( 0L,NULL, 0L );

		crcValue = crc32( crcValue, (const Bytef*)[data bytes], (unsigned int)[data length] );
		ret = zipOpenNewFileInZip3( _zipFile,
                                   (const char*) [newname UTF8String],
                                   &zipInfo,
                                   NULL,0,
                                   NULL,0,
                                   NULL,//comment
                                   Z_DEFLATED,
                                   compressionLevel,
                                   0,
                                   15,
                                   8,
                                   Z_DEFAULT_STRATEGY,
                                   [_password cStringUsingEncoding:NSASCIIStringEncoding],
                                   crcValue );
	}
	if( ret!=Z_OK )
	{
        [data release];
		return NO;
	}
    
    // M_FRAGMENT_SIZE 10000000 (10MB)
    FILE *f = fopen([file cStringUsingEncoding:NSUTF8StringEncoding], "r");
    if(!f)
        return NO;
    
    fseek(f, 0, SEEK_END);
    long fLenght = ftell(f);
    rewind(f);
    void *fBuffer = malloc(M_FRAGMENT_SIZE);
    
    for (;fLenght > M_FRAGMENT_SIZE; fLenght-=M_FRAGMENT_SIZE) {
        fread(fBuffer, 1, M_FRAGMENT_SIZE, f);
        ret = zipWriteInFileInZip( _zipFile, (const void*)fBuffer, M_FRAGMENT_SIZE);
    }
    
    if(fLenght) {
        fread(fBuffer, 1, fLenght, f);
        ret = zipWriteInFileInZip( _zipFile, (const void*)fBuffer, (unsigned int)fLenght);
        if( ret!=Z_OK )
        {
            free(fBuffer);
            fclose(f);
            return NO;
        }
    }
    free(fBuffer);
    fclose(f);
    
	if( ret!=Z_OK )
	{
		return NO;
	}
	ret = zipCloseFileInZip( _zipFile );
	if( ret!=Z_OK )
		return NO;
	return YES;
}

/**
 * Close a zip file after creating and added files to it.
 *
 * @returns BOOL YES on success
 */

-(BOOL) CloseZipFile2
{
	self.password = nil;
	if( _zipFile==NULL )
		return NO;
	BOOL ret =  zipClose( _zipFile,NULL )==Z_OK?YES:NO;
	_zipFile = NULL;
	return ret;
}

/**
 * open an existing zip file ready for expanding.
 *
 * @param zipFile     the path to a zip file to be opened.
 * @returns BOOL YES on success
 */

-(BOOL) UnzipOpenFile:(NSString*) zipFile
{
    // create an array to receive the list of unzipped files.
    if (_unzippedFiles) [_unzippedFiles release];
    _unzippedFiles = [[NSMutableArray alloc] initWithCapacity:1];
    
	_unzFile = unzOpen( (const char*)[zipFile UTF8String] );
	if( _unzFile )
	{
		unz_global_info  globalInfo = {0};
		if( unzGetGlobalInfo(_unzFile, &globalInfo )==UNZ_OK )
		{
            _numFiles = (unsigned int)globalInfo.number_entry;
			//VERBOSE("%lu entries in the zip file", globalInfo.number_entry);
		}
	}
	return _unzFile!=NULL;
}

/**
 * open an existing zip file with a password ready for expanding.
 *
 * @param zipFile     the path to a zip file to be opened.
 * @param password    the password to use decrpyting the file.
 * @returns BOOL YES on success
 */

-(BOOL) UnzipOpenFile:(NSString*) zipFile Password:(NSString*) password
{
	self.password = password;
	return [self UnzipOpenFile:zipFile];
}

/**
 * Expand all files in the zip archive into the specified directory.
 *
 * If a delegate has been set and responds to OverWriteOperation: it can
 * return YES to overwrite a file, or NO to skip that file.
 *
 * On completion, the property `unzippedFiles` will be an array populated
 * with the full paths of each file that was successfully expanded.
 *
 * @param path    the directory where expanded files will be created
 * @param overwrite    should existing files be overwritten
 * @returns BOOL YES on success
 */

-(BOOL) UnzipFileTo:(NSString*) path overWrite:(BOOL) overwrite
{
	BOOL success = YES;
    int index = 0;
    int progress = -1;
	int ret = unzGoToFirstFile( _unzFile );
	unsigned char		buffer[4096] = {0};
	if( ret!=UNZ_OK )
	{
		[self OutputErrorMessage:@"Failed"];
	}
    
	const char* password = [_password cStringUsingEncoding:NSASCIIStringEncoding];
	
	do{
        @autoreleasepool {
            if( [_password length]==0 )
                ret = unzOpenCurrentFile( _unzFile );
            else
                ret = unzOpenCurrentFilePassword( _unzFile, password );
            if( ret!=UNZ_OK )
            {
                [self OutputErrorMessage:@"Error occurs"];
                success = NO;
                break;
            }
            // reading data and write to file
            int read ;
            unz_file_info	fileInfo ={0};
            ret = unzGetCurrentFileInfo(_unzFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
            if( ret!=UNZ_OK )
            {
                [self OutputErrorMessage:@"Error occurs while getting file info"];
                success = NO;
                unzCloseCurrentFile( _unzFile );
                break;
            }
            char* filename = (char*) malloc( fileInfo.size_filename +1 );
            unzGetCurrentFileInfo(_unzFile, &fileInfo, filename, fileInfo.size_filename + 1, NULL, 0, NULL, 0);
            filename[fileInfo.size_filename] = '\0';
            
            // check if it contains directory
            NSString * strPath = [NSString stringWithCString:filename encoding:self.stringEncoding];
            BOOL isDirectory = NO;
            if( filename[fileInfo.size_filename-1]=='/' || filename[fileInfo.size_filename-1]=='\\')
                isDirectory = YES;
            free( filename );
            if( [strPath rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]].location!=NSNotFound )
            {// contains a path
                strPath = [strPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
            }
            NSString* fullPath = [path stringByAppendingPathComponent:strPath];
            
            if( isDirectory )
                [_fileManager createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:nil error:nil];
            else
                [_fileManager createDirectoryAtPath:[fullPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
            
            FILE* fp = NULL;
            do
            {
                read = unzReadCurrentFile(_unzFile, buffer, 4096);
                if (read >= 0)
                {
                    if (fp == NULL) {
                        if( [_fileManager fileExistsAtPath:fullPath] && !isDirectory && !overwrite )
                        {
                            if( ![self OverWrite:fullPath] )
                            {
                                // don't process any more of the file, but continue
                                break;
                            }
                        }
                        if (!isDirectory) {
                            fp = fopen( (const char*)[fullPath UTF8String], "wb");
                            if (fp == NULL) {
                                [self OutputErrorMessage:@"Failed to open output file for writing"];
                                break;
                            }
                        }
                    }
                    fwrite(buffer, read, 1, fp );
                }
                else // if (read < 0)
                {
                    ret = read; // result will be an error code
                    success = NO;
                    [self OutputErrorMessage:@"Failed to read zip file"];
                }
            } while (read > 0);
            
            if (fp)
            {
                fclose( fp );
                
                // add the full path of this file to the output array
                [(NSMutableArray*)_unzippedFiles addObject:fullPath];
                
                // set the orignal datetime property
                if( fileInfo.dosDate!=0 )
                {
                    NSDate* orgDate = [[NSDate alloc]
                                       initWithTimeInterval:(NSTimeInterval)fileInfo.dosDate
                                       sinceDate:[self Date1980] ];
                    
                    NSDictionary* attr = [NSDictionary dictionaryWithObject:orgDate forKey:NSFileModificationDate]; //[_fileManager fileAttributesAtPath:fullPath traverseLink:YES];
                    if( attr )
                    {
                        //	[attr  setValue:orgDate forKey:NSFileCreationDate];
                        if( ![_fileManager setAttributes:attr ofItemAtPath:fullPath error:nil] )
                        {
                            // cann't set attributes 
                            //VERBOSE("Failed to set attributes");
                        }
                        
                    }
                    [orgDate release];
                    orgDate = nil;
                }
                
            }
            
            if (ret == UNZ_OK) {
                ret = unzCloseCurrentFile( _unzFile );
                if (ret != UNZ_OK) {
                    [self OutputErrorMessage:@"file was unzipped but failed crc check"];
                    success = NO;
                }
            }
            
            if (ret == UNZ_OK) {
                ret = unzGoToNextFile( _unzFile );
            }
            
            if (_progressBlock && _numFiles) {
                index++;
                int p = index*100/_numFiles;
                progress = p;
                _progressBlock(progress, index, _numFiles);
            }
        }
	} while (ret==UNZ_OK && ret!=UNZ_END_OF_LIST_OF_FILE);
	return success;
}

/**
 * Close the zip file.
 *
 * @returns BOOL YES on success
 */

-(BOOL) UnzipCloseFile
{
	self.password = nil;
	if( _unzFile ) {
		int err = unzClose( _unzFile );
        _unzFile = nil;
        return err ==UNZ_OK;
    }
	return YES;
}


/**
 * Return a list of filenames that are in the zip archive. 
 * No path information is available as this can be called before the zip is expanded.
 *
 * @returns NSArray list of filenames in the zip archive. 
 */

-(NSArray*) getZipFileContents     // list the contents of the zip archive. must be called after UnzipOpenFile
{
    int ret = unzGoToFirstFile( _unzFile );
    NSMutableArray * allFilenames = [NSMutableArray arrayWithCapacity:40];
    
    if( ret!=UNZ_OK )
    {
        [self OutputErrorMessage:@"Failed"];
    }
    
    const char* password = [_password cStringUsingEncoding:NSASCIIStringEncoding];
    
    do{
        if( [_password length]==0 )
            ret = unzOpenCurrentFile( _unzFile );
        else
            ret = unzOpenCurrentFilePassword( _unzFile, password );
        if( ret!=UNZ_OK )
        {
            [self OutputErrorMessage:@"Error occured"];
            break;
        }
        
        // reading data and write to file
        unz_file_info   fileInfo ={0};
        ret = unzGetCurrentFileInfo(_unzFile, &fileInfo, NULL, 0, NULL, 0, NULL, 0);
        if( ret!=UNZ_OK )
        {
            [self OutputErrorMessage:@"Error occurs while getting file info"];
            unzCloseCurrentFile( _unzFile );
            break;
        }
        char* filename = (char*) malloc( fileInfo.size_filename +1 );
        unzGetCurrentFileInfo(_unzFile, &fileInfo, filename, fileInfo.size_filename + 1, NULL, 0, NULL, 0);
        filename[fileInfo.size_filename] = '\0';
        
        // check if it contains directory
        NSString * strPath = [NSString stringWithCString:filename encoding:NSASCIIStringEncoding];
        free( filename );
        if( [strPath rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\"]].location!=NSNotFound )
        {// contains a path
            strPath = [strPath stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
        }
        
        // Copy name to array
        [allFilenames addObject:strPath];
        
        unzCloseCurrentFile( _unzFile );
        ret = unzGoToNextFile( _unzFile );
    }  while( ret==UNZ_OK && UNZ_OK!=UNZ_END_OF_LIST_OF_FILE );
    
    // return an immutable array.
    return [NSArray arrayWithArray:allFilenames];
}


#pragma mark wrapper for delegate

/**
 * send the ErrorMessage: to the delegate if it responds to it.
 */
-(void) OutputErrorMessage:(NSString*) msg
{
	if( _delegate && [_delegate respondsToSelector:@selector(ErrorMessage:)] )
		[_delegate ErrorMessage:msg];
}

/**
 * send the OverWriteOperation: selector to the delegate if it responds to it,
 * returning the result, or YES by default.
 */

-(BOOL) OverWrite:(NSString*) file
{
	if( _delegate && [_delegate respondsToSelector:@selector(OverWriteOperation:)] )
		return [_delegate OverWriteOperation:file];
	return YES;
}

#pragma mark get NSDate object for 1980-01-01
-(NSDate*) Date1980
{
	NSDateComponents *comps = [[NSDateComponents alloc] init];
	[comps setDay:1];
	[comps setMonth:1];
	[comps setYear:1980];
	NSCalendar *gregorian = [[NSCalendar alloc]
							 initWithCalendarIdentifier:NSGregorianCalendar];
	NSDate *date = [gregorian dateFromComponents:comps];
	
	[comps release];
	[gregorian release];
	return date;
}

-(BOOL) openZipFile2:(NSString*) zipFile
{
    _zipFile = zipOpen( (const char*)[zipFile UTF8String], APPEND_STATUS_ADDINZIP);
    if( !_zipFile )
        return NO;
    return YES;
}


@end


@implementation NSFileManager(ZipArchive)

- (NSDictionary *)_attributesOfItemAtPath:(NSString *)path followingSymLinks:(BOOL)followingSymLinks error:(NSError **)error
{
    // call file manager default action, which is to not follow symlinks
    NSDictionary* results = [self attributesOfItemAtPath:path error:error];
    if (followingSymLinks && results && (error ? *error == nil : YES)) {
        if ([[results fileType] isEqualToString:NSFileTypeSymbolicLink]) {
            // follow the symlink
            NSString* realPath = [self destinationOfSymbolicLinkAtPath:path error:error];
            if (realPath && (error ? *error == nil : YES)) {
                return [self _attributesOfItemAtPath:realPath followingSymLinks:followingSymLinks error:error];
            } else {
                // failure to resolve symlink should be an error returning nil and error will already be set.
                return nil;
            }
        }
    }
    return results;
}

@end

