#import "crack.h"
#import "out.h"
#import <Foundation/Foundation.h>
#import "ZipArchive.h"
#include <sys/stat.h>

int overdrive_enabled = 0;
BOOL ios6 = FALSE;
BOOL* sixtyfour = FALSE;

void hexify(unsigned char *data, uint32_t size){
    while(size--)
        printf("%02x", *data++);
}

BOOL dump_binary(FILE *origin, FILE *target, uint32_t top, NSString *originPath, NSString* finalPath) {
    if (sixtyfour) {
        return dump_binary_64(origin, target, top, originPath, finalPath);
    }
    else {
        return dump_binary_32(origin, target, top, originPath, finalPath);
    }
}
long fsize(const char *file) {
    struct stat st;
    if (stat(file, &st) == 0)
        return st.st_size;
    
    return -1;
}
ZipArchive * createZip(NSString *file) {
    ZipArchive *archiver = [[ZipArchive alloc] init];
    
    if (!file) {
        DEBUG("File string is nil");
        
        return nil;
    }
    
    [archiver CreateZipFile2:file];
    
    return archiver;
}

void zip(ZipArchive *archiver, NSString *folder) {
    BOOL isDir = NO;
    
    NSArray *subpaths;
    NSUInteger total = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:folder isDirectory:&isDir] && isDir){
        subpaths = [fileManager subpathsAtPath:folder];
        total = [subpaths count];
    }
    
    // I vaguely remember that this is a bad idea on 64-bit but I'm not 100% on that
    int togo = (int)total;
    
    
    for(NSString *path in subpaths){
		togo--;
        
        PERCENT((int)ceil((((double)total - togo) / (double)total) * 100));
        
        // Only add it if it's not a directory. ZipArchive will take care of those.
        NSString *longPath = [folder stringByAppendingPathComponent:path];
        
        if([fileManager fileExistsAtPath:longPath isDirectory:&isDir] && !isDir){
            [archiver addFileToZip:longPath newname:path compressionLevel:compression_level];
        }
    }
    return;
}

void zip_original(ZipArchive *archiver, NSString *folder, NSString *binary, NSString* zip) {
    long size;
    BOOL isDir=NO;
    
    NSArray *subpaths;
    NSUInteger total = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:folder isDirectory:&isDir] && isDir){
        subpaths = [fileManager subpathsAtPath:folder];
        total = [subpaths count];
    }
    
    int togo = (int)total;
    
    
    for(NSString *path in subpaths) {
		togo--;
        
        if (([path rangeOfString:@".app"].location != NSNotFound) && ([path rangeOfString:@"SC_Info"].location == NSNotFound) && ([path rangeOfString:@"Library"].location == NSNotFound) && ([path rangeOfString:@"tmp"].location == NSNotFound) && ([path rangeOfString:[NSString stringWithFormat:@".app/%@", binary]].location == NSNotFound)) {
            PERCENT((int)ceil((((double)total - togo) / (double)total) * 100));
            
            // Only add it if it's not a directory. ZipArchive will take care of those.
            NSString *longPath = [folder stringByAppendingPathComponent:path];
            
            if([fileManager fileExistsAtPath:longPath isDirectory:&isDir] && !isDir){
                size += fsize([longPath UTF8String]);
                [archiver addFileToZip:longPath newname:[NSString stringWithFormat:@"Payload/%@", path] compressionLevel:compression_level];
            }
        }
    }
    
    return;
}


NSString * crack_application(NSString *application_basedir, NSString *basename, NSString* version) {
    VERBOSE("Creating working directory...");
    
	NSString *workingDir = [NSString stringWithFormat:@"%@%@/", @"/tmp/clutch_", genRandStringLength(8)];
	if (![[NSFileManager defaultManager] createDirectoryAtPath:[workingDir stringByAppendingFormat:@"Payload/%@", basename] withIntermediateDirectories:YES attributes:[NSDictionary
                                                                                                                                                                        dictionaryWithObjects:[NSArray arrayWithObjects:@"mobile", @"mobile", nil]
                                                                                                                                                                        forKeys:[NSArray arrayWithObjects:@"NSFileOwnerAccountName", @"NSFileGroupOwnerAccountName", nil]
                                                                                                                                                                        ] error:NULL]) {
		printf("error: Could not create working directory\n");
		return nil;
	}
	
    VERBOSE("Performing initial analysis...");
	struct stat statbuf_info;
	stat([[application_basedir stringByAppendingString:@"Info.plist"] UTF8String], &statbuf_info);
	time_t ist_atime = statbuf_info.st_atime;
	time_t ist_mtime = statbuf_info.st_mtime;
	struct utimbuf oldtimes_info;
	oldtimes_info.actime = ist_atime;
	oldtimes_info.modtime = ist_mtime;
	
	NSMutableDictionary *infoplist = [NSMutableDictionary dictionaryWithContentsOfFile:[application_basedir stringByAppendingString:@"Info.plist"]];
	if (infoplist == nil) {
		printf("error: Could not open Info.plist\n");
		goto fatalc;
	}
	
	if ([(NSString *)[ClutchConfiguration getValue:@"CheckMinOS"] isEqualToString:@"YES"]) {
		NSString *MinOS;
		if (nil != (MinOS = [infoplist objectForKey:@"MinimumOSVersion"])) {
			if (strncmp([MinOS UTF8String], "2", 1) == 0) {
				printf("notice: added SignerIdentity field (MinOS 2.X)\n");
				[infoplist setObject:@"Apple iPhone OS Application Signing" forKey:@"SignerIdentity"];
				[infoplist writeToFile:[application_basedir stringByAppendingString:@"Info.plist"] atomically:NO];
			}
		}
	}
	
	utime([[application_basedir stringByAppendingString:@"Info.plist"] UTF8String], &oldtimes_info);
	
	NSString *binary_name = [infoplist objectForKey:@"CFBundleExecutable"];
	
	NSString *fbinary_path = init_crack_binary(application_basedir, basename, workingDir, infoplist);
	if (fbinary_path == nil) {
		printf("error: Could not crack binary\n");
		goto fatalc;
	}
	
	NSMutableDictionary *metadataPlist = [NSMutableDictionary dictionaryWithContentsOfFile:[application_basedir stringByAppendingString:@"/../iTunesMetadata.plist"]];
	
	[[NSFileManager defaultManager] copyItemAtPath:[application_basedir stringByAppendingString:@"/../iTunesArtwork"] toPath:[workingDir stringByAppendingString:@"iTunesArtwork"] error:NULL];
    
	if (![[ClutchConfiguration getValue:@"RemoveMetadata"] isEqualToString:@"YES"]) {
        VERBOSE("Censoring iTunesMetadata.plist...");
		struct stat statbuf_metadata;
		stat([[application_basedir stringByAppendingString:@"/../iTunesMetadata.plist"] UTF8String], &statbuf_metadata);
		time_t mst_atime = statbuf_metadata.st_atime;
		time_t mst_mtime = statbuf_metadata.st_mtime;
		struct utimbuf oldtimes_metadata;
		oldtimes_metadata.actime = mst_atime;
		oldtimes_metadata.modtime = mst_mtime;
		
        NSString *fake_email;
        NSDate *fake_purchase_date = [NSDate dateWithTimeIntervalSince1970:1251313938];
        
        if (nil == (fake_email = [ClutchConfiguration getValue:@"MetadataEmail"])) {
            fake_email = @"steve@rim.jobs";
        }
        
        if (nil == (fake_purchase_date = [ClutchConfiguration getValue:@"MetadataPurchaseDate"])) {
            fake_purchase_date = [NSDate dateWithTimeIntervalSince1970:1251313938];
        }
        
		NSDictionary *censorList = [NSDictionary dictionaryWithObjectsAndKeys:fake_email, @"appleId", fake_purchase_date, @"purchaseDate", nil];
		if ([[ClutchConfiguration getValue:@"CheckMetadata"] isEqualToString:@"YES"]) {
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
            if (censorItem == nil) {
                DEBUG("nil key");
            } else {
                [metadataPlist setObject:[censorList objectForKey:censorItem] forKey:censorItem];
            }
		}
		[metadataPlist removeObjectForKey:@"com.apple.iTunesStore.downloadInfo"];
		[metadataPlist writeToFile:[workingDir stringByAppendingString:@"iTunesMetadata.plist"] atomically:NO];
		utime([[workingDir stringByAppendingString:@"iTunesMetadata.plist"] UTF8String], &oldtimes_metadata);
		utime([[application_basedir stringByAppendingString:@"/../iTunesMetadata.plist"] UTF8String], &oldtimes_metadata);
	}
	
	NSString *crackerName = [ClutchConfiguration getValue:@"CrackerName"];
    if (crackerName == nil) {
        crackerName = @"no-name-cracker";
    }
	if ([[ClutchConfiguration getValue:@"CreditFile"] isEqualToString:@"YES"]) {
        VERBOSE("Creating credit file...");
		FILE *fh = fopen([[workingDir stringByAppendingFormat:@"_%@", crackerName] UTF8String], "w");
		NSString *creditFileData = [NSString stringWithFormat:@"%@ (%@) Cracked by %@ using %s.", [infoplist objectForKey:@"CFBundleDisplayName"], [infoplist objectForKey:@"CFBundleVersion"], crackerName, CLUTCH_VERSION];
		fwrite([creditFileData UTF8String], [creditFileData lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 1, fh);
		fclose(fh);
	}
    
    if (overdrive_enabled) {
        VERBOSE("Including overdrive dylib...");
        [[NSFileManager defaultManager] copyItemAtPath:@"/var/lib/clutch/overdrive.dylib" toPath:[workingDir stringByAppendingFormat:@"Payload/%@/overdrive.dylib", basename] error:NULL];
        
        VERBOSE("Creating fake SC_Info data...");
        // create fake SC_Info directory
        [[NSFileManager defaultManager] createDirectoryAtPath:[workingDir stringByAppendingFormat:@"Payload/%@/SF_Info/", basename] withIntermediateDirectories:YES attributes:nil error:NULL];
        VERBOSE("DEBUG: made fake directory");
        // create fake SC_Info SINF file
        FILE *sinfh = fopen([[workingDir stringByAppendingFormat:@"Payload/%@/SF_Info/%@.sinf", basename, binary_name] UTF8String], "w");
        void *sinf = generate_sinf([[metadataPlist objectForKey:@"itemId"] intValue], (char *)[crackerName UTF8String], [[metadataPlist objectForKey:@"vendorId"] intValue]);
        fwrite(sinf, CFSwapInt32(*(uint32_t *)sinf), 1, sinfh);
        fclose(sinfh);
        free(sinf);
        
        // create fake SC_Info SUPP file
        FILE *supph = fopen([[workingDir stringByAppendingFormat:@"Payload/%@/SF_Info/%@.supp", basename, binary_name] UTF8String], "w");
        uint32_t suppsize;
        void *supp = generate_supp(&suppsize);
        fwrite(supp, suppsize, 1, supph);
        fclose(supph);
        free(supp);
    }
    
    VERBOSE("Packaging IPA file...");
    
    // filename addendum
    NSMutableString *addendum = [[NSMutableString alloc]init];
    
    if (overdrive_enabled) {
        [addendum appendString:@"-OD"];
    }
    if ([(NSString *)[ClutchConfiguration getValue:@"CheckMinOS"] isEqualToString:@"YES"]) {
        [addendum appendString: [NSString stringWithFormat:@"-iOS-%@", [infoplist objectForKey:@"MinimumOSVersion"]]];
    }
    
	NSString *ipapath;
    NSString *bundleName;
    
    if (infoplist[@"CFBundleDisplayName"] == nil || infoplist[@"CFBundleDisplayName"] == NULL) {
        DEBUG("using CFBundleName");
        bundleName = infoplist[@"CFBundleName"];
    } else {
        bundleName = infoplist[@"CFBundleDisplayName"];
    }
    
	if ([[ClutchConfiguration getValue:@"FilenameCredit"] isEqualToString:@"YES"]) {
		ipapath = [NSString stringWithFormat:@"/var/root/Documents/Cracked/%@-v%@-%@%@-(%@).ipa", [bundleName stringByReplacingOccurrencesOfString:@"/" withString:@"_"], [infoplist objectForKey:@"CFBundleVersion"], crackerName, addendum, [NSString stringWithUTF8String:CLUTCH_VERSION]];
	} else {
		ipapath = [NSString stringWithFormat:@"/var/root/Documents/Cracked/%@-v%@%@-(%@).ipa", [bundleName stringByReplacingOccurrencesOfString:@"/" withString:@"_"], [infoplist objectForKey:@"CFBundleVersion"], addendum, [NSString stringWithUTF8String:CLUTCH_VERSION]];
	}
	[[NSFileManager defaultManager] createDirectoryAtPath:@"/var/root/Documents/Cracked/" withIntermediateDirectories:TRUE attributes:nil error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:ipapath error:NULL];
    
	int config_compression = [[ClutchConfiguration getValue:@"CompressionLevel"] intValue];
	if (!((config_compression < 10) && (config_compression > -2))) {
        printf("error: unknown compression level");
        goto fatalc;
    }
    else {
        compression_level = config_compression;
    }
    printf("\ncompression level: %d\n", compression_level);
    
    
    if (new_zip == 1) {
        NOTIFY("Compressing original application (native zip) (1/2)...");
        ZipArchive *archiver = createZip(ipapath);
        zip_original(archiver, [application_basedir stringByAppendingString:@"../"], binary_name, ipapath);
        stop_bar();
        NOTIFY("Compressing second cracked application (native zip) (2/2)...");
        zip(archiver, workingDir);
        stop_bar();
        [archiver CloseZipFile2];
    }
    else {
        
        NSString *compressionArguments = @"";
        if (compression_level != -1) {
            compressionArguments = [NSString stringWithFormat:@"-%d", compression_level];
        }
        NOTIFY("Compressing cracked application (1/2)...");
        system([[NSString stringWithFormat:@"cd %@; zip %@ -m -r \"%@\" * 2>&1> /dev/null", workingDir, compressionArguments, ipapath] UTF8String]);
        [[NSFileManager defaultManager] moveItemAtPath:[workingDir stringByAppendingString:@"Payload"] toPath:[workingDir stringByAppendingString:@"Payload_1"] error:NULL];
        
        
        [[NSFileManager defaultManager] createSymbolicLinkAtPath:[workingDir stringByAppendingString:@"Payload"] withDestinationPath:[application_basedir stringByAppendingString:@"/../"] error:NULL];
        NOTIFY("Compressing original application (2/2)...");
        system([[NSString stringWithFormat:@"cd %@; zip %@ -u -y -r -n .jpg:.JPG:.jpeg:.png:.PNG:.gif:.GIF:.Z:.gz:.zip:.zoo:.arc:.lzh:.rar:.arj:.mp3:.mp4:.m4a:.m4v:.ogg:.ogv:.avi:.flac:.aac \"%@\" Payload/* -x Payload/iTunesArtwork Payload/iTunesMetadata.plist \"Payload/Documents/*\" \"Payload/Library/*\" \"Payload/tmp/*\" \"Payload/*/%@\" \"Payload/*/SC_Info/*\" 2>&1> /dev/null", workingDir, compressionArguments, ipapath, binary_name] UTF8String]);
        
        stop_bar();
        
    }
    
	[[NSFileManager defaultManager] removeItemAtPath:workingDir error:NULL];
    
 
    NSMutableDictionary *dict;
        
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/etc/clutch_cracked.plist"]) {
        dict = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/etc/clutch_cracked.plist"];
    } else {
        [[NSFileManager defaultManager] createFileAtPath:@"/etc/clutch_cracked.plist" contents:nil attributes:nil];
        dict = [[NSMutableDictionary alloc] init];
    }
        
    [dict setObject:version forKey:bundleName];
    [dict writeToFile:@"/etc/clutch_cracked.plist" atomically:YES];
        
    [dict release];
    
	return ipapath;
	
fatalc:
	[[NSFileManager defaultManager] removeItemAtPath:workingDir error:NULL];
	return nil;
}
NSString * init_crack_binary(NSString *application_basedir, NSString *bdir, NSString *workingDir, NSDictionary *infoplist) {
    VERBOSE("Performing cracking preflight...");
	NSString *binary_name = [infoplist objectForKey:@"CFBundleExecutable"];
	NSString *binary_path = [application_basedir stringByAppendingString:binary_name];
	NSString *fbinary_path = [workingDir stringByAppendingFormat:@"Payload/%@/%@", bdir, binary_name];
	
	NSString *err = nil;
	
	struct stat statbuf;
	stat([binary_path UTF8String], &statbuf);
	time_t bst_atime = statbuf.st_atime;
	time_t bst_mtime = statbuf.st_mtime;
	
	NSString *ret = crack_binary(binary_path, fbinary_path, &err);
	
	struct utimbuf oldtimes;
	oldtimes.actime = bst_atime;
	oldtimes.modtime = bst_mtime;
	
	utime([binary_path UTF8String], &oldtimes);
	utime([fbinary_path UTF8String], &oldtimes);
	
	if (ret == nil)
		printf("error: %s\n", [err UTF8String]);
	
	return ret;
}

int get_arch(struct fat_arch* arch) {
    int i;
    if (arch->cputype == CPUTYPE_32) {
        DEBUG("32bit portion detected %u", arch->cpusubtype);
        switch (arch->cpusubtype) {
            case ARMV7S_SUBTYPE:
                DEBUG("armv7s portion detected");
                i = 11;
                break;
            case ARMV7_SUBTYPE:
                DEBUG("armv7 portion detected");
                i = 9;
                break;
            case ARMV6_SUBTYPE:
                DEBUG("armv6 portion detected");
                i = 6;
                break;
            default:
                DEBUG("ERROR: unknown 32bit portion detected %u", arch->cpusubtype);
                i = -1;
                break;
        }
    }
    else if (arch->cputype == CPUTYPE_64) {
        switch (arch->cpusubtype) {
            case ARM64_SUBTYPE:
                DEBUG("arm64 portion detected! 64bit!!");
                i = 64;
                break;
            default:
                DEBUG("ERROR: unknown 64bit portion detected");
                i = -1;
                break;
        }
    }
    return i;
}

/*NSString* strip_arch(NSString* binaryPath, NSString* baseDirectory, NSString* baseName, uint32_t keep_arch) {
    NSString* suffix = [NSString stringWithFormat:@"arm%u_lwork", CFSwapInt32(keep_arch)];
    NSString *lipoPath = [NSString stringWithFormat:@"%@_%@", binaryPath, suffix]; // assign a new lipo path
    
    DEBUG("lipopath %s", [lipoPath UTF8String]);
    
    FILE *lipoOut = fopen([lipoPath UTF8String], "w+"); // prepare the file stream
    DEBUG("opened lipo");
    FILE* binary = fopen([binaryPath UTF8String], "r+");
    DEBUG("opened binary");
    char stripBuffer[4096];
    fseek(binary, SEEK_SET, 0);
    DEBUG("seeked binary");
    fread(&stripBuffer, sizeof(buffer), 1, binary);
    DEBUG("READ HEADER");
    DEBUG("read header");
    struct fat_header* fh = (struct fat_header*) (stripBuffer);
    struct fat_arch* arch = (struct fat_arch *) &fh[1];
    struct fat_arch keep;
    
    for (int i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
        if (arch->cpusubtype == keep_arch) {
            DEBUG("found arch to keep %u! Storing it", CFSwapInt32(keep_arch));
            keep = *arch;
            break;
        }
        arch++;
    }
    
    fseek(binary, CFSwapInt32(keep.offset), SEEK_SET); // go to the lipo offset

    void *tmp_b = malloc(0x1000); // allocate a temporary buffer
    uint32_t remain = CFSwapInt32(keep.size);
    
    DEBUG("performing liposuction!!!");
    
    while (remain > 0) {
        if (remain > 0x1000) {
            // move over 0x1000
            fread(tmp_b, 0x1000, 1, binary);
            fwrite(tmp_b, 0x1000, 1, lipoOut);
            remain -= 0x1000;
        } else {
            // move over remaining and break
            fread(tmp_b, remain, 1, binary);
            fwrite(tmp_b, remain, 1, lipoOut);
            break;
        }
        DEBUG("remain %u", remain);
    }
    
    free(tmp_b); // free temporary buffer
    
    fseek(lipoOut, 0, SEEK_SET);
    struct mach_header header;
    fread(&header, sizeof(struct mach_header), 1, lipoOut);
    DEBUG("mach header flags");
    hexify((unsigned char*)&header.flags, sizeof(header.flags));
    DEBUG("mach header cpu %u %u", header.cpusubtype, header.cputype);
    
    fclose(lipoOut); // close lipo output stream
    fclose(binary);
    
    chown([lipoPath UTF8String], 501, 501); // adjust permissions
    chmod([lipoPath UTF8String], 0777); // adjust permissions
    
      DEBUG("copying sc_info files!");
    NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
    sinf_file = [NSString stringWithFormat:@"%@_%@.sinf", scinfo_prefix, suffix];
    supp_file = [NSString stringWithFormat:@"%@_%@.supp", scinfo_prefix, suffix];
    supf_file = [NSString stringWithFormat:@"%@_%@.supf", scinfo_prefix, suffix];
    if ([[NSFileManager defaultManager] fileExistsAtPath:supf_file]) {
        [[NSFileManager defaultManager] moveItemAtPath:[scinfo_prefix stringByAppendingString:@".supf"] toPath:supf_file error:NULL];
    }
    NSLog(@"sinf file yo %@", sinf_file);
    [[NSFileManager defaultManager] moveItemAtPath:[scinfo_prefix stringByAppendingString:@".sinf"] toPath:sinf_file error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:[scinfo_prefix stringByAppendingString:@".supp"] toPath:supp_file error:NULL];
    //int *p = NULL;
    //*p = 1;
   return lipoPath;
}*/

NSString* strip_arch(NSString* binaryPath, NSString* baseDirectory, NSString* baseName, uint32_t keep_arch) {
    DEBUG("##### STRIPPING ARCH #####");
    NSString* suffix = [NSString stringWithFormat:@"arm%u_lwork", CFSwapInt32(keep_arch)];
    NSString *lipoPath = [NSString stringWithFormat:@"%@_%@", binaryPath, suffix]; // assign a new lipo path
    DEBUG("lipo path %s", [lipoPath UTF8String]);
    [[NSFileManager defaultManager] copyItemAtPath:binaryPath toPath:lipoPath error: NULL];
    FILE *lipoOut = fopen([lipoPath UTF8String], "r+"); // prepare the file stream
    char stripBuffer[4096];
    fseek(lipoOut, SEEK_SET, 0);
    fread(&stripBuffer, sizeof(buffer), 1, lipoOut);
    struct fat_header* fh = (struct fat_header*) (stripBuffer);
    struct fat_arch* arch = (struct fat_arch *) &fh[1];
    struct fat_arch copy;
    BOOL foundarch = FALSE;
    
    fseek(lipoOut, 8, SEEK_SET); //skip nfat_arch and bin_magic
    
    
    for (int i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
        if (arch->cpusubtype == keep_arch) {
            DEBUG("found arch to keep %u! Storing it", CFSwapInt32(keep_arch));
            foundarch = TRUE;
            fread(&copy, sizeof(struct fat_arch), 1, lipoOut);
        }
        else {
            fseek(lipoOut, sizeof(struct fat_arch), SEEK_CUR);
        }
        arch++;
    }
    if (!foundarch) {
        DEBUG("error: could not find arch to keep!");
        int *p = NULL;
        *p = 1;
        return false;
    }
    fseek(lipoOut, 8, SEEK_SET);
    fwrite(&copy, sizeof(struct fat_arch), 1, lipoOut);
    char data[20];
    memset(data,'\0',sizeof(data));
    for (int i = 0; i < (CFSwapInt32(fh->nfat_arch) - 1); i++) {
        DEBUG("blanking arch! %u", i);
        fwrite(data, sizeof(data), 1, lipoOut);
    }
    
    //change nfat_arch
    DEBUG("changing nfat_arch");
    
    //fseek(lipoOut, 4, SEEK_SET); //bin_magic
    //fread(&bin_nfat_arch, 4, 1, lipoOut); // get the number of fat architectures in the file
    //VERBOSE("DEBUG: number of architectures %u", CFSwapInt32(bin_nfat_arch));
    uint32_t bin_nfat_arch = 0x1000000;
    
    DEBUG("number of architectures %u", CFSwapInt32(bin_nfat_arch));
    fseek(lipoOut, 4, SEEK_SET); //bin_magic
    fwrite(&bin_nfat_arch, 4, 1, lipoOut);
    
    DEBUG("Written new header to binary!");
    fclose(lipoOut);
    DEBUG("copying sc_info files!");
    NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
    sinf_file = [NSString stringWithFormat:@"%@_%@.sinf", scinfo_prefix, suffix];
    supp_file = [NSString stringWithFormat:@"%@_%@.supp", scinfo_prefix, suffix];
    supf_file = [NSString stringWithFormat:@"%@_%@.supf", scinfo_prefix, suffix];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[scinfo_prefix stringByAppendingString:@".supf"]]) {
        [[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".supf"] toPath:supf_file error:NULL];
    }
    NSLog(@"sinf file yo %@", sinf_file);
    [[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".sinf"] toPath:sinf_file error:NULL];
    [[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".supp"] toPath:supp_file error:NULL];
 
    return lipoPath;
    
}


NSString* swap_arch(NSString *binaryPath, NSString* baseDirectory, NSString* baseName, uint32_t swaparch) {
    char swapBuffer[4096];
    DEBUG("##### SWAPPING ARCH #####");
    DEBUG("local cpu_type %u", CFSwapInt32(get_local_cputype()));
    uint32_t local_arch = get_local_cpusubtype();
    if (local_arch == swaparch) {
        NSLog(@"UH HELLRO PLIS");
        return NULL;
    }
    
    NSString *orig_old_path = binaryPath; // save old binary path
    NSString* suffix = [NSString stringWithFormat:@"arm%u_lwork", CFSwapInt32(swaparch)];
    binaryPath = [NSString stringWithFormat:@"%@_%@", binaryPath, suffix]; // assign new path
    
   [[NSFileManager defaultManager] copyItemAtPath:orig_old_path toPath:binaryPath error: NULL];
    
    FILE* swapbinary = fopen([binaryPath UTF8String], "r+");
    
    fseek(swapbinary, 0, SEEK_SET);
    fread(&swapBuffer, sizeof(swapBuffer), 1, swapbinary);
    struct fat_header* swapfh = (struct fat_header*) (swapBuffer);
    
    
    //moveItemAtPath:orig_old_path toPath:binaryPath error:NULL];
    // swap the architectures
    
    bool swap1 = FALSE, swap2 = FALSE;
    int i;
    
    
    struct fat_arch *arch = (struct fat_arch *) &swapfh[1];
    uint32_t swap_cputype, largest_cpusubtype = 0;
    NSLog(@"arch arch arch ok ok");
    
    for (i = CFSwapInt32(swapfh->nfat_arch); i--;) {
        if (arch->cpusubtype == swaparch) {
            DEBUG("found arch to swap! %u", CFSwapInt32(swaparch));
            swap_cputype = arch->cputype;
        }
        if (arch->cpusubtype > largest_cpusubtype) {
            largest_cpusubtype = arch->cpusubtype;
        }
        arch++;
    }
    DEBUG("largest_cpusubtype: %u", CFSwapInt32(largest_cpusubtype));
    
    arch = (struct fat_arch *) &swapfh[1];
    
    for (i = CFSwapInt32(swapfh->nfat_arch); i--;) {
        if (arch->cpusubtype == largest_cpusubtype) {
            if (swap_cputype != arch->cputype) {
                DEBUG("ERROR: cputypes to swap are incompatible!");
                return false;
            }
            arch->cpusubtype = swaparch;
            DEBUG("swapp swapp: replaced %u's cpusubtype to %u", CFSwapInt32(arch->cpusubtype), CFSwapInt32(swaparch));
        }
        else if (arch->cpusubtype == swaparch) {
            arch->cpusubtype = largest_cpusubtype;
            DEBUG("swap swap: replaced %u's cpusubtype to %u", CFSwapInt32(arch->cpusubtype), CFSwapInt32(largest_cpusubtype));
        }
        arch++;
    }
    
    
//move the SC_Info keys

    NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
    sinf_file = [NSString stringWithFormat:@"%@_%@.sinf", scinfo_prefix, suffix];
    supp_file = [NSString stringWithFormat:@"%@_%@.supp", scinfo_prefix, suffix];
    NSLog(@"sinf file yo %@", sinf_file);
    supf_file = [NSString stringWithFormat:@"%@_%@.supf", scinfo_prefix, suffix];
    if ([[NSFileManager defaultManager] fileExistsAtPath:[scinfo_prefix stringByAppendingString:@".supf"]]) {
        [[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".supf"] toPath:supf_file error:NULL];
    }
    [[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".sinf"] toPath:sinf_file error:NULL];
    [[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".supp"] toPath:supp_file error:NULL];
    
    fseek(swapbinary, 0, SEEK_SET);
    fwrite(swapBuffer, sizeof(swapBuffer), 1, swapbinary);
    DEBUG("swap: Wrote new arch info");
    fclose(swapbinary);
    
    return binaryPath;
    
}

/*
void swap_back(NSString *binaryPath, NSString* baseDirectory, NSString* baseName) {
    // remove swapped binary
    NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
    [[NSFileManager defaultManager] removeItemAtPath:binaryPath error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:sinf_file toPath:[scinfo_prefix stringByAppendingString:@".sinf"] error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:supp_file toPath:[scinfo_prefix stringByAppendingString:@".supp"] error:NULL];
    if ([[NSFileManager defaultManager] fileExistsAtPath:supf_file]) {
        [[NSFileManager defaultManager] moveItemAtPath:supf_file toPath:[scinfo_prefix stringByAppendingString:@".supf"] error:NULL];
    }
    
    VERBOSE("DEBUG: Removed SC_Info files");
}*/

void swap_back(NSString *binaryPath, NSString* baseDirectory, NSString* baseName) {
    // remove swapped binary
    [[NSFileManager defaultManager] removeItemAtPath:binaryPath error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:sinf_file error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:supp_file error:NULL];
    if ([[NSFileManager defaultManager] fileExistsAtPath:supf_file]) {
        [[NSFileManager defaultManager] removeItemAtPath:supf_file error:NULL];
    }
    DEBUG("Removed SC_Info files");
}

NSString *crack_binary(NSString *binaryPath, NSString *finalPath, NSString **error) {
    stripHeaders = [[NSMutableArray alloc] init];
	local_cpusubtype = get_local_cpusubtype();
    local_cputype = get_local_cputype();
    
    [[NSFileManager defaultManager] copyItemAtPath:binaryPath toPath:finalPath error:NULL]; // move the original binary to that path
   	NSString *baseName = [binaryPath lastPathComponent]; // get the basename (name of the binary)
	NSString *baseDirectory = [NSString stringWithFormat:@"%@/", [binaryPath stringByDeletingLastPathComponent]]; // get the base directory
	
	// open streams from both files
	FILE *oldbinary, *newbinary;
	oldbinary = fopen([binaryPath UTF8String], "r+");
	newbinary = fopen([finalPath UTF8String], "r+");
	
    fread(&buffer, sizeof(buffer), 1, oldbinary);
    struct fat_header* fh = (struct fat_header*) (buffer);
    
    struct fat_arch armv6, armv7, armv7s, arm64, lipo;
    struct fat_arch *arch;
    
    int i;
    
    DEBUG("############################");
    DEBUG("local_cpusubtype %u", local_cpusubtype);
    DEBUG("############################");
    
    if (fh->magic == FAT_CIGAM) {
        VERBOSE("binary is a fat executable");
        
        bool has_armv6 = FALSE;
        bool has_armv7 = FALSE;
        bool has_armv7s = FALSE;
        bool has_arm64 = FALSE;
        //NSMutableArray* available_archs = [[NSMutableArray alloc] init];
        arch = (struct fat_arch *) &fh[1];
        
        // for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
        //apparently this is faster? I think so too.
        for (i = CFSwapInt32(fh->nfat_arch); i--;) {
            //[available_archs addObject:[NSNumber numberWithUnsignedInteger:arch->cpusubtype]];
            //VERBOSE("DEBUG: cpusubtype %u %u", arch->cpusubtype, arch->cputype);
            switch (get_arch(arch)) {
                case 6:
                    armv6 = *arch;
                    has_armv6 = TRUE;
                    break;
                case 9:
                    armv7 = *arch;
                    has_armv7 = TRUE;
                    break;
                case 11:
                    armv7s = *arch;
                    has_armv7s = TRUE;
                    break;
                case 64:
                    arm64 = *arch;
                    has_arm64 = TRUE;
                    break;
                case -1:
                    *error = @"Unknown architecture detected.";
                    goto c_err;
                    break;
            }
            DEBUG("local_cputype: %u, arch_cpusubtype: %u, local_cpusubtype: %u", CFSwapInt32(local_cputype), CFSwapInt32(arch->cpusubtype), local_cpusubtype);
            if ((local_cputype == CPUTYPE_32) && (CFSwapInt32(arch->cpusubtype) > local_cpusubtype)) {
                DEBUG("Can't crack arch %d on %d! skipping", CFSwapInt32(arch->cpusubtype), local_cpusubtype);
                [stripHeaders addObject:[NSNumber numberWithUnsignedInt:arch->cpusubtype]];
            }
            else if (arch->cputype == CPUTYPE_64) {
                if ((local_cputype == CPUTYPE_64) && (CFSwapInt32(arch->cpusubtype) > local_cpusubtype)) {
                    DEBUG("Can't crack 64bit arch %d on %d! skipping", CFSwapInt32(arch->cpusubtype), local_cpusubtype);
                    [stripHeaders addObject:[NSNumber numberWithUnsignedInt:arch->cpusubtype]];
                }
                else if (local_cputype == CPUTYPE_32) {
                    DEBUG("Can't crack 64bit arch on this device! skipping");
                    [stripHeaders addObject:[NSNumber numberWithUnsignedInt:arch->cpusubtype]];
                }
            }
            /*else if ((arch->cpusubtype == arm64_SUBTYPE) && (local_arch != arm64)) {
             VERBOSE("DEBUG: Can't crack arm64 on non-arm64! skipping");
             [stripHeaders addObject:[NSNumber numberWithUnsignedInt:arm64_SUBTYPE]];
             }
             else if ((local_arch == ARMV6) && (CFSwapInt32(arch->cpusubtype) > ARMV6)) {
             VERBOSE("DEBUG: Can't crack >armv6 on armv6! skipping");
             [stripHeaders addObject:[NSNumber numberWithUnsignedInt:CFSwapInt32(arch->cpusubtype)]];
             }*/
            arch++;
        }
        
        if ((CFSwapInt32(fh->nfat_arch) - [stripHeaders count]) == 1) {
            arch = (struct fat_arch *) &fh[1];
            for (i = CFSwapInt32(fh->nfat_arch); i--;) {
                //for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
                NSNumber* subtype = [NSNumber numberWithUnsignedInt:arch->cpusubtype];
                if (![stripHeaders containsObject:subtype]) {
                    lipo = *arch;
                    goto c_lipo;
                    break;
                }
                arch++;
            }
            
        }
        
        // Running on an armv7, armv7s, arm64, or higher device
        //fat binary
        DEBUG("fat binary");
        
       
        
        arch = (struct fat_arch *) &fh[1];
        for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
            sixtyfour = FALSE;
            DEBUG("Currently cracking arch %u", CFSwapInt32(arch->cpusubtype));
            if (arch->cputype == CPUTYPE_64) {
                sixtyfour = TRUE;
            }
            
            DEBUG("############################");
            DEBUG("cpu_subtype: %u local_cpusubtype: %u\n", CFSwapInt32(arch->cpusubtype), local_cpusubtype);
            DEBUG("offset: %u", CFSwapInt32(arch->offset));
            DEBUG("############################");
            
            if (local_cpusubtype != CFSwapInt32(arch->cpusubtype)) {
                if ([stripHeaders containsObject:[NSNumber numberWithUnsignedInt:arch->cpusubtype]]) {
                    DEBUG("skipping");
                    arch++;
                    continue;
                }
                printf("swap: Currently cracking armv%u portion\n", CFSwapInt32(arch->cpusubtype));
                DEBUG("cpusubtype isn't the same as local arch! swapping");
                
                //only keep the one we want
                //NSMutableArray* stripArray = available_archs;
                //[stripArray removeObject:[NSNumber numberWithUnsignedInteger:arch->cpusubtype]];
                
                DEBUG("stripping arch");
                
                NSString* newPath;
                
                if (has_arm64) {
                    newPath = strip_arch(binaryPath, baseDirectory, baseName, arch->cpusubtype);
                }
                else {
                    newPath = swap_arch(binaryPath, baseDirectory, baseName, arch->cpusubtype);
                }
                
               
                FILE* swapbinary = fopen([newPath UTF8String], "r+");
                DEBUG("dumping lipoed portion");
                if (!dump_binary(swapbinary, newbinary, CFSwapInt32(arch->offset), newPath, finalPath)) {
                    // Dumping failed
                    stop_bar();
                    *error = @"Cannot crack swapped portion of binary.";
                    swap_back(newPath, baseDirectory, baseName);
                    goto c_err;
                }
                swap_back(newPath, baseDirectory, baseName);
            }
            else {
                if (!dump_binary(oldbinary, newbinary, CFSwapInt32(arch->offset), binaryPath, finalPath)) {
                    // Dumping failed
                    stop_bar();
                    *error = @"Cannot crack unswapped portion of binary.";
                    goto c_err;
                }
            }
            arch++;
        }
    }
    else {
        VERBOSE("Application is a thin binary, cracking single architecture...");
        if (arch->cputype == CPUTYPE_64) {
            sixtyfour = TRUE;
        }
        // Application is a thin binary
        
        NOTIFY("dumping binary...");
        
        if (!dump_binary(oldbinary, newbinary, 0, binaryPath, finalPath)) {
            // Dump failed
            stop_bar();
            *error = @"Cannot crack thin binary.";
            goto c_err;
        }
        stop_bar();
        /*struct mach_header mh;
         struct load_command lc;
         struct encryption_info_command *crypt;
         
         fseek(newbinary, 0, SEEK_SET);
         fread(&mh, sizeof(struct mach_header), 1, newbinary);
         VERBOSE("fread sucessful!");
         for (int lc_index = 0; lc_index < mh.ncmds; lc_index++) {
         fread(&lc, sizeof(struct load_command), 1, newbinary);
         VERBOSE("loopy loopy %u", lc.cmd);
         if (lc-.cmd == LC_ENCRYPTION_INFO) {
         VERBOSE("LC_ENCRYPTION!!!!");
         fseek(newbinary, -1 * sizeof(struct load_command), SEEK_CUR);
         fread(&crypt, sizeof(struct encryption_info_command), 1, newbinary);
         if (crypt->cryptid == 0) {
         VERBOSE("DEBUG: cryptid was patched!");
         break;
         }
         else {
         VERBOSE("warning: cryptid not patched.. patching again!");
         crypt->cryptid = 0;
         fseek(newbinary, -1 * sizeof(struct encryption_info_command), SEEK_CUR);
         fwrite(&crypt, sizeof(struct encryption_info_command), 1, newbinary);
         break;
         }
         }
         else {
         fseek(newbinary, lc->cmdsize - sizeof(struct load_command), SEEK_CUR); // seek over the load command
         }
         }*/
        goto c_complete;
    }
    //check cryptid
    

    //9 11 6
    struct fat_arch copy, doh;
    fpos_t copypos, rempos;
    NSNumber* stripHeader;
    for (id item in stripHeaders) {
        NOTIFY("Removing unwanted header information..");
        stripHeader = (NSNumber*) item;
        
        NSString *lipoPath = [NSString stringWithFormat:@"%@_l", finalPath]; // assign a new lipo path
        [[NSFileManager defaultManager] copyItemAtPath:finalPath toPath:lipoPath error: NULL];
        FILE *lipoOut = fopen([lipoPath UTF8String], "r+"); // prepare the file stream
        char stripBuffer[4096];
        fseek(lipoOut, SEEK_SET, 0);
        fread(&stripBuffer, sizeof(buffer), 1, lipoOut);
        fh = (struct fat_header*) (stripBuffer);
        arch = (struct fat_arch *) &fh[1];
        
        fseek(lipoOut, 8, SEEK_SET); //skip nfat_arch and bin_magic
        
        for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
            DEBUG("STIPHEADER: %d", [stripHeader unsignedIntValue]);
            fread(&doh, sizeof(struct fat_arch), 1, lipoOut);
            if (arch->cpusubtype == [stripHeader unsignedIntValue]) {
                DEBUG("Found arch to strip! Storing it");
                if (i < CFSwapInt32(fh->nfat_arch)) {
                    fgetpos(lipoOut, &copypos);
                    DEBUG("copy position %lld", copypos);
                }
                else {
                    DEBUG("ERROR: Dunno where to store ler0-i09483430470374 help!!!!!");
                }
            }
            else if (i == (CFSwapInt32(fh->nfat_arch)) - 1) {
                copy = doh;
                fgetpos(lipoOut, &rempos);
                DEBUG("remove position %lld", rempos);
            }
            arch++;
        }
        
        fh = (struct fat_header*) (stripBuffer);
        arch = (struct fat_arch *) &fh[1];
        for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
            if (arch->cpusubtype == [stripHeader unsignedIntValue])  {
                rempos = rempos - sizeof(struct fat_arch);
                fseek(lipoOut,rempos, SEEK_SET);
                DEBUG("rempos %lld", rempos);
                char data[20];
                memset(data,'\0',sizeof(data));
                fwrite(data, sizeof(data), 1, lipoOut);
            }
            else if (i == (CFSwapInt32(fh->nfat_arch) - 1)) {
                copypos = copypos - sizeof(struct fat_arch);
                DEBUG("copypos %lld", copypos);
                fseek(lipoOut, copypos, SEEK_SET);
                fwrite(&copy, sizeof(struct fat_arch), 1, lipoOut);
            }
            arch++;
        }
        
        DEBUG("changing nfat_arch");
        uint32_t bin_nfat_arch;
        
        fseek(lipoOut, 4, SEEK_SET); //bin_magic
        fread(&bin_nfat_arch, 4, 1, lipoOut); // get the number of fat architectures in the file
        DEBUG("number of architectures %u", CFSwapInt32(bin_nfat_arch));
        bin_nfat_arch = bin_nfat_arch - 0x1000000;
        
        DEBUG("number of architectures %u", CFSwapInt32(bin_nfat_arch));
        fseek(lipoOut, 4, SEEK_SET); //bin_magic
        fwrite(&bin_nfat_arch, 4, 1, lipoOut);
        
        DEBUG("Written new header to binary!");
        fclose(lipoOut);
        [[NSFileManager defaultManager] removeItemAtPath:finalPath error:NULL];
        [[NSFileManager defaultManager] moveItemAtPath:lipoPath toPath:finalPath error:NULL];
        
    }
    fclose(newbinary); // close the new binary stream
    fclose(oldbinary); // close the old binary stream
    return finalPath; // return  cracked binary path
	
c_lipo:
    printf("Can only crack one architecture!\n");
    DEBUG("lipo offset %u", CFSwapInt32(lipo.offset));
    if (!dump_binary(oldbinary, newbinary, CFSwapInt32(lipo.offset), binaryPath, finalPath)) {
        // Dumping failed
        stop_bar();
        *error = [NSString stringWithFormat:@"Cannot crack armv%u portion", get_arch(&lipo)];
        goto c_err;
    }
    stop_bar();
    
    NOTIFY("Performing liposuction of mach object...");
    
    // Lipo out the data
    NSString *lipoPath = [NSString stringWithFormat:@"%@_l", finalPath]; // assign a new lipo path
    FILE *lipoOut = fopen([lipoPath UTF8String], "w+"); // prepare the file stream
    fseek(newbinary, CFSwapInt32(lipo.offset), SEEK_SET); // go to the armv6 offset
    void *tmp_b = malloc(0x1000); // allocate a temporary buffer
    
    uint32_t remain = CFSwapInt32(lipo.size);
    
    while (remain > 0) {
        if (remain > 0x1000) {
            // move over 0x1000
            fread(tmp_b, 0x1000, 1, newbinary);
            fwrite(tmp_b, 0x1000, 1, lipoOut);
            remain -= 0x1000;
        } else {
            // move over remaining and break
            fread(tmp_b, remain, 1, newbinary);
            fwrite(tmp_b, remain, 1, lipoOut);
            break;
        }
    }
    
    free(tmp_b); // free temporary buffer
    fclose(lipoOut); // close lipo output stream
    fclose(newbinary); // close new binary stream
    fclose(oldbinary); // close old binary stream
    
    [[NSFileManager defaultManager] removeItemAtPath:finalPath error:NULL]; // remove old file
    [[NSFileManager defaultManager] moveItemAtPath:lipoPath toPath:finalPath error:NULL]; // move the lipo'd binary to the final path
    chown([finalPath UTF8String], 501, 501); // adjust permissions
    chmod([finalPath UTF8String], 0777); // adjust permissions
    
    return finalPath;
    
c_complete:
    fclose(newbinary); // close the new binary stream
	fclose(oldbinary); // close the old binary stream
	return finalPath; // return cracked binary path
	
c_err:
	fclose(newbinary); // close the new binary stream
	fclose(oldbinary); // close the old binary stream
	[[NSFileManager defaultManager] removeItemAtPath:finalPath error:NULL]; // delete the new binary
	return nil;
}


NSString * genRandStringLength(int len) {
	NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
	NSString *letters = @"abcdef0123456789";
	
	for (int i=0; i<len; i++) {
		[randomString appendFormat: @"%c", [letters characterAtIndex: arc4random()%[letters length]]];
	}
	
	return randomString;
}

uint32_t get_local_cputype() {
    const struct mach_header *header = _dyld_get_image_header(0);
    uint32_t cputype = (uint32_t)header->cputype;
    //DEBUG("header header header yo %u %u", header->cpusubtype, cputype);
    
    DEBUG("######## CPU INFO ########");
    if (cputype == 12) {
       DEBUG("local_cputype: 32bit");
        return CPUTYPE_32;
    }
    else {
        DEBUG("local_cputype: 64bit");
        return CPUTYPE_64;
    }
    return -1;
    
}

uint32_t get_local_cpusubtype() {
    //Name of image (includes full path)
    const struct mach_header *header = _dyld_get_image_header(0);
    DEBUG("header header header yo %u %u", header->cpusubtype, header->cputype);
    return header->cpusubtype;
}


