//
//  Packager.m
//  Clutch
//
//  Created by Ninja on 22/01/2014.
//
//

#import "Packager.h"
#import "archive.h"
#import "archive_entry.h"

@implementation Packager

void write_archive(const char *outname, const char **filename)
{
    struct archive *archive = archive_write_new();
    assert(archive != NULL);
    
    struct archive_entry *entry;
    struct stat st;
    
    char buf[8192];
    int len;
    int fd;
    
    if ((archive_write_set_format_zip(archive) != ARCHIVE_OK) || archive_write_open_filename(archive, "test.zip") != ARCHIVE_OK)
    {
        // Error handle
        NSLog(@"Error creating ZIP object.");
    }
    
    archive_entry_set_pathname(entry, *filename);
    archive_entry_set_size(entry, len);
    archive_entry_set_filetype(entry, AE_IFREG);
    archive_entry_set_perm(entry, 0644);
    
    int rc = archive_write_header(archive, entry);
    
    archive_entry_free(entry);
    entry = NULL;
    
    if (ARCHIVE_OK != rc)
    {
        // Error handle
        NSLog(@"error idk");
    }
    
    size_t writtern = archive_write_data(archive, buf, len);
    
    if (writtern != len)
    {
        // Error handle
        NSLog(@"Some other error idk");
    }
    
    archive_write_free(archive);
    
    
    
}



@end
