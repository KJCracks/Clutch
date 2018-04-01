/* zip.h -- IO on .zip files using zlib
   Version 1.1, February 14h, 2010
   part of the MiniZip project - ( http://www.winimage.com/zLibDll/minizip.html )

   Copyright (C) 1998-2010 Gilles Vollant (minizip) ( http://www.winimage.com/zLibDll/minizip.html )

   Modifications for Zip64 support
   Copyright (C) 2009-2010 Mathias Svensson ( http://result42.com )

   For more info read MiniZip_info.txt

   ---------------------------------------------------------------------------

   Condition of use and distribution are the same than zlib :

   This software is provided 'as-is', without any express or implied
   warranty.  In no event will the authors be held liable for any damages
   arising from the use of this software.

   Permission is granted to anyone to use this software for any purpose,
   including commercial applications, and to alter it and redistribute it
   freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you must not
      claim that you wrote the original software. If you use this software
      in a product, an acknowledgment in the product documentation would be
      appreciated but is not required.
   2. Altered source versions must be plainly marked as such, and must not be
      misrepresented as being the original software.
   3. This notice may not be removed or altered from any source distribution.

   ---------------------------------------------------------------------------
*/

#ifndef _zip12_H
#define _zip12_H

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _ZLIB_H
#include "zlib.h"
#endif

#ifndef _ZLIBIOAPI_H
#include "ioapi.h"
#endif

#ifdef HAVE_BZIP2
#include "bzlib.h"
#endif

#define Z_BZIP2ED 12

#if defined(STRICTZIP) || defined(STRICTZIPUNZIP)
/* like the STRICT of WIN32, we define a pointer that cannot be converted
    from (void*) without cast */
typedef struct TagzipFile__ {
    int unused;
} zipFile__;
typedef zipFile__ *zipFile;
#else
typedef voidp zipFile;
#endif

#define ZIP_OK (0)
#define ZIP_EOF (0)
#define ZIP_ERRNO (Z_ERRNO)
#define ZIP_PARAMERROR (-102)
#define ZIP_BADZIPFILE (-103)
#define ZIP_INTERNALERROR (-104)

#ifndef DEF_MEM_LEVEL
#if MAX_MEM_LEVEL >= 8
#define DEF_MEM_LEVEL 8
#else
#define DEF_MEM_LEVEL MAX_MEM_LEVEL
#endif
#endif
/* default memLevel */

/* tm_zip contain date/time info */
typedef struct tm_zip_s {
    uInt tm_sec;  /* seconds after the minute - [0,59] */
    uInt tm_min;  /* minutes after the hour - [0,59] */
    uInt tm_hour; /* hours since midnight - [0,23] */
    uInt tm_mday; /* day of the month - [1,31] */
    uInt tm_mon;  /* months since January - [0,11] */
    uInt tm_year; /* years - [1980..2044] */
} tm_zip;

typedef struct {
    tm_zip tmz_date;   /* date in understandable format           */
    uLong dosDate;     /* if dos_date == 0, tmu_date is used      */
    uLong internal_fa; /* internal file attributes        2 bytes */
    uLong external_fa; /* external file attributes        4 bytes */
} zip_fileinfo;

typedef const char *zipcharpc;

#define APPEND_STATUS_CREATE (0)
#define APPEND_STATUS_CREATEAFTER (1)
#define APPEND_STATUS_ADDINZIP (2)

/***************************************************************************/
/* Writing a zip file */

extern zipFile ZEXPORT zipOpen OF((const char *pathname, int append));
extern zipFile ZEXPORT zipOpen64 OF((const void *pathname, int append));
/* Create a zipfile.

   pathname should contain the full pathname (by example, on a Windows XP computer
      "c:\\zlib\\zlib113.zip" or on an Unix computer "zlib/zlib113.zip".

   return NULL if zipfile cannot be opened
   return zipFile handle if no error

   If the file pathname exist and append == APPEND_STATUS_CREATEAFTER, the zip
   will be created at the end of the file. (useful if the file contain a self extractor code)
   If the file pathname exist and append == APPEND_STATUS_ADDINZIP, we will add files in existing
   zip (be sure you don't add file that doesn't exist)

   NOTE: There is no delete function into a zipfile. If you want delete file into a zipfile,
   you must open a zipfile, and create another. Of course, you can use RAW reading and writing to copy
   the file you did not want delete. */

extern zipFile ZEXPORT zipOpen2
    OF((const char *pathname, int append, zipcharpc *globalcomment, zlib_filefunc_def *pzlib_filefunc_def));

extern zipFile ZEXPORT zipOpen2_64
    OF((const void *pathname, int append, zipcharpc *globalcomment, zlib_filefunc64_def *pzlib_filefunc_def));

extern zipFile ZEXPORT zipOpen3 OF((const char *pathname,
                                    int append,
                                    ZPOS64_T disk_size,
                                    zipcharpc *globalcomment,
                                    zlib_filefunc_def *pzlib_filefunc_def));
/* Same as zipOpen2 but allows specification of spanned zip size */

extern zipFile ZEXPORT zipOpen3_64 OF((const void *pathname,
                                       int append,
                                       ZPOS64_T disk_size,
                                       zipcharpc *globalcomment,
                                       zlib_filefunc64_def *pzlib_filefunc_def));

extern int ZEXPORT zipOpenNewFileInZip OF((zipFile file,
                                           const char *filename,
                                           const zip_fileinfo *zipfi,
                                           const void *extrafield_local,
                                           uInt size_extrafield_local,
                                           const void *extrafield_global,
                                           uInt size_extrafield_global,
                                           const char *comment,
                                           int method,
                                           int level));
/* Open a file in the ZIP for writing.

   filename : the filename in zip (if NULL, '-' without quote will be used
   *zipfi contain supplemental information
   extrafield_local buffer to store the local header extra field data, can be NULL
   size_extrafield_local size of extrafield_local buffer
   extrafield_global buffer to store the global header extra field data, can be NULL
   size_extrafield_global size of extrafield_local buffer
   comment buffer for comment string
   method contain the compression method (0 for store, Z_DEFLATED for deflate)
   level contain the level of compression (can be Z_DEFAULT_COMPRESSION)
   zip64 is set to 1 if a zip64 extended information block should be added to the local file header.
   this MUST be '1' if the uncompressed size is >= 0xffffffff. */

extern int ZEXPORT zipOpenNewFileInZip64 OF((zipFile file,
                                             const char *filename,
                                             const zip_fileinfo *zipfi,
                                             const void *extrafield_local,
                                             uInt size_extrafield_local,
                                             const void *extrafield_global,
                                             uInt size_extrafield_global,
                                             const char *comment,
                                             int method,
                                             int level,
                                             int zip64));
/* Same as zipOpenNewFileInZip with zip64 support */

extern int ZEXPORT zipOpenNewFileInZip2 OF((zipFile file,
                                            const char *filename,
                                            const zip_fileinfo *zipfi,
                                            const void *extrafield_local,
                                            uInt size_extrafield_local,
                                            const void *extrafield_global,
                                            uInt size_extrafield_global,
                                            const char *comment,
                                            int method,
                                            int level,
                                            int raw));
/* Same as zipOpenNewFileInZip, except if raw=1, we write raw file */

extern int ZEXPORT zipOpenNewFileInZip2_64 OF((zipFile file,
                                               const char *filename,
                                               const zip_fileinfo *zipfi,
                                               const void *extrafield_local,
                                               uInt size_extrafield_local,
                                               const void *extrafield_global,
                                               uInt size_extrafield_global,
                                               const char *comment,
                                               int method,
                                               int level,
                                               int raw,
                                               int zip64));
/* Same as zipOpenNewFileInZip3 with zip64 support */

extern int ZEXPORT zipOpenNewFileInZip3 OF((zipFile file,
                                            const char *filename,
                                            const zip_fileinfo *zipfi,
                                            const void *extrafield_local,
                                            uInt size_extrafield_local,
                                            const void *extrafield_global,
                                            uInt size_extrafield_global,
                                            const char *comment,
                                            int method,
                                            int level,
                                            int raw,
                                            int windowBits,
                                            int memLevel,
                                            int strategy,
                                            const char *password,
                                            uLong crcForCrypting));
/* Same as zipOpenNewFileInZip2, except
    windowBits, memLevel, strategy : see parameter strategy in deflateInit2
    password : crypting password (NULL for no crypting)
    crcForCrypting : crc of file to compress (needed for crypting) */

extern int ZEXPORT zipOpenNewFileInZip3_64 OF((zipFile file,
                                               const char *filename,
                                               const zip_fileinfo *zipfi,
                                               const void *extrafield_local,
                                               uInt size_extrafield_local,
                                               const void *extrafield_global,
                                               uInt size_extrafield_global,
                                               const char *comment,
                                               int method,
                                               int level,
                                               int raw,
                                               int windowBits,
                                               int memLevel,
                                               int strategy,
                                               const char *password,
                                               uLong crcForCrypting,
                                               int zip64));
/* Same as zipOpenNewFileInZip3 with zip64 support */

extern int ZEXPORT zipOpenNewFileInZip4 OF((zipFile file,
                                            const char *filename,
                                            const zip_fileinfo *zipfi,
                                            const void *extrafield_local,
                                            uInt size_extrafield_local,
                                            const void *extrafield_global,
                                            uInt size_extrafield_global,
                                            const char *comment,
                                            int method,
                                            int level,
                                            int raw,
                                            int windowBits,
                                            int memLevel,
                                            int strategy,
                                            const char *password,
                                            uLong crcForCrypting,
                                            uLong versionMadeBy,
                                            uLong flagBase));
/* Same as zipOpenNewFileInZip3 except versionMadeBy & flag fields */

extern int ZEXPORT zipOpenNewFileInZip4_64 OF((zipFile file,
                                               const char *filename,
                                               const zip_fileinfo *zipfi,
                                               const void *extrafield_local,
                                               uInt size_extrafield_local,
                                               const void *extrafield_global,
                                               uInt size_extrafield_global,
                                               const char *comment,
                                               int method,
                                               int level,
                                               int raw,
                                               int windowBits,
                                               int memLevel,
                                               int strategy,
                                               const char *password,
                                               uLong crcForCrypting,
                                               uLong versionMadeBy,
                                               uLong flagBase,
                                               int zip64));
/* Same as zipOpenNewFileInZip4 with zip64 support */

extern int ZEXPORT zipWriteInFileInZip OF((zipFile file, const void *buf, unsigned len));
/* Write data in the zipfile */

extern int ZEXPORT zipCloseFileInZip OF((zipFile file));
/* Close the current file in the zipfile */

extern int ZEXPORT zipCloseFileInZipRaw OF((zipFile file, uLong uncompressed_size, uLong crc32));
extern int ZEXPORT zipCloseFileInZipRaw64 OF((zipFile file, ZPOS64_T uncompressed_size, uLong crc32));
/* Close the current file in the zipfile, for file opened with parameter raw=1 in zipOpenNewFileInZip2
   uncompressed_size and crc32 are value for the uncompressed size */

extern int ZEXPORT zipClose OF((zipFile file, const char *global_comment));
/* Close the zipfile */

/***************************************************************************/

#ifdef __cplusplus
}
#endif

#endif /* _zip64_H */
