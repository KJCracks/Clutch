//
//  imetadata.c
//  Clutch
//
//  Created by Zorro on 30.12.13.
//
//

#import "imetadata.h"
#import "Prefs.h"

#import <sys/stat.h>
#import <sys/types.h>
#import <utime.h>

void generateMetadata(NSString *origPath,NSString *output)
{
    struct stat statbuf_metadata;
    stat(origPath.UTF8String, &statbuf_metadata);
    time_t mst_atime = statbuf_metadata.st_atime;
    time_t mst_mtime = statbuf_metadata.st_mtime;
    struct utimbuf oldtimes_metadata;
    oldtimes_metadata.actime = mst_atime;
    oldtimes_metadata.modtime = mst_mtime;
    
    NSString *fake_email;
    NSDate *fake_purchase_date = [NSDate dateWithTimeIntervalSince1970:1251313938];
    
    if (nil == (fake_email = [[Prefs sharedInstance] objectForKey:@"MetadataEmail"])) {
        fake_email = @"steve@rim.jobs";
    }
    
    fake_purchase_date = [NSDate date];
    
    NSMutableDictionary *metadataPlist = [NSMutableDictionary dictionaryWithContentsOfFile:origPath];
    
    NSDictionary *censorList = [NSDictionary dictionaryWithObjectsAndKeys:fake_email, @"appleId", fake_purchase_date, @"purchaseDate", nil];
    if ([[Prefs sharedInstance] boolForKey:@"CheckMetadata"]) {
        NSDictionary *noCensorList = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"", @"artistId",
                                      @"", @"artistName",
                                      @"", @"buy-only",
                                      @"", @"buyParams",
                                      @"", @"copyright",
                                      @"", @"drmVersionNumber",
                                      @"", @"fileExtension",
                                      @"", @"genre",
                                      @"", @"genreId",
                                      @"", @"itemId",
                                      @"", @"itemName",
                                      @"", @"gameCenterEnabled",
                                      @"", @"gameCenterEverEnabled",
                                      @"", @"kind",
                                      @"", @"playlistArtistName",
                                      @"", @"playlistName",
                                      @"", @"price",
                                      @"", @"priceDisplay",
                                      @"", @"rating",
                                      @"", @"releaseDate",
                                      @"", @"s",
                                      @"", @"softwareIcon57x57URL",
                                      @"", @"softwareIconNeedsShine",
                                      @"", @"softwareSupportedDeviceIds",
                                      @"", @"softwareVersionBundleId",
                                      @"", @"softwareVersionExternalIdentifier",
                                      @"", @"UIRequiredDeviceCapabilities",
                                      @"", @"softwareVersionExternalIdentifiers",
                                      @"", @"subgenres",
                                      @"", @"vendorId",
                                      @"", @"versionRestrictions",
                                      @"", @"com.apple.iTunesStore.downloadInfo",
                                      @"", @"bundleVersion",
                                      @"", @"bundleShortVersionString",
                                      @"", @"product-type",
                                      @"", @"is-purchased-redownload",
                                      @"", @"asset-info", nil];
        for (id plistItem in metadataPlist) {
            if (([noCensorList objectForKey:plistItem] == nil) && ([censorList objectForKey:plistItem] == nil)) {
                printf("\033[0;37;41mwarning: iTunesMetadata.plist item named '\033[1;37;41m%s\033[0;37;41m' is unrecognized\033[0m\n", [plistItem UTF8String]);
            }
        }
    }
    
    for (id censorItem in censorList) {
        [metadataPlist setObject:[censorList objectForKey:censorItem] forKey:censorItem];
    }
    [metadataPlist removeObjectForKey:@"com.apple.iTunesStore.downloadInfo"];
    
    [metadataPlist writeToFile:output atomically:NO];
    utime(output.UTF8String, &oldtimes_metadata);
    utime(origPath.UTF8String, &oldtimes_metadata);
}


