#import "crack.h"
#import "out.h"
#import <Foundation/Foundation.h>
#import "ZipArchive.h"
#include <sys/stat.h>

int overdrive_enabled = 0;
BOOL ios6 = FALSE;

long fsize(const char *file) {
    struct stat st;
    if (stat(file, &st) == 0)
        return st.st_size;
    
    return -1;
}
ZipArchive * createZip(NSString *file) {
    ZipArchive *archiver = [[ZipArchive alloc] init];
    [archiver CreateZipFile2:file];
    return archiver;
}

void zip(ZipArchive *archiver, NSString *folder) {
    BOOL isDir=NO;
    NSArray *subpaths;
    int total = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:folder isDirectory:&isDir] && isDir){
        subpaths = [fileManager subpathsAtPath:folder];
        total = [subpaths count];
    }
    int togo = total;
    
    
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
    int total = 0;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:folder isDirectory:&isDir] && isDir){
        subpaths = [fileManager subpathsAtPath:folder];
        total = [subpaths count];
    }
    int togo = total;
    
    
    for(NSString *path in subpaths) {
		togo--;
        if (([path rangeOfString:@".app"].location != NSNotFound) && ([path rangeOfString:@"SC_Info"].location == NSNotFound) && ([path rangeOfString:@"Library"].location == NSNotFound) && ([path rangeOfString:@"tmp"].location == NSNotFound) && ([path rangeOfString:[NSString stringWithFormat:@".app/%@", binary]].location == NSNotFound)) {
            PERCENT((int)ceil((((double)total - togo) / (double)total) * 100));
            // Only add it if it's not a directory. ZipArchive will take care of those.
            NSString *longPath = [folder stringByAppendingPathComponent:path];
            if([fileManager fileExistsAtPath:longPath isDirectory:&isDir] && !isDir){
                size += fsize([longPath UTF8String]);
                /*if (size > 31457280){
                 VERBOSE("Zip went over 30MB, saving..");
                 [archiver CloseZipFile2];
                 [archiver release];
                 archiver = [[ZipArchive alloc] init];
                 [archiver openZipFile2:zip];
                 [archiver ]
                 }*/
                [archiver addFileToZip:longPath newname:[NSString stringWithFormat:@"Payload/%@", path] compressionLevel:compression_level];
            }
        }
    }
    return;
}


NSString * crack_application(NSString *application_basedir, NSString *basename, NSString* version) {
    VERBOSE("Creating working directory...");
    
    stripHeaders = [[NSMutableArray alloc] init];
    local_arch = get_local_arch();
    local_cputype = get_local_cputype();
    
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
			[metadataPlist setObject:[censorList objectForKey:censorItem] forKey:censorItem];
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
        NSLog(@"DEBUG: made fake directory");
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
    
    NSLog(@"addenum: %@", addendum);
         
	NSString *ipapath;
	if ([[ClutchConfiguration getValue:@"FilenameCredit"] isEqualToString:@"YES"]) {
		ipapath = [NSString stringWithFormat:@"/var/root/Documents/Cracked/%@-v%@-%@%@-(%@).ipa", [[infoplist objectForKey:@"CFBundleDisplayName"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"], [infoplist objectForKey:@"CFBundleVersion"], crackerName, addendum, [NSString stringWithUTF8String:CLUTCH_VERSION]];
	} else {
		ipapath = [NSString stringWithFormat:@"/var/root/Documents/Cracked/%@-v%@%@-(%@).ipa", [[infoplist objectForKey:@"CFBundleDisplayName"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"], [infoplist objectForKey:@"CFBundleVersion"], addendum, [NSString stringWithUTF8String:CLUTCH_VERSION]];
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
    printf("compression level: %d\n", compression_level);
    
    
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
    }
    else {
        [[NSFileManager defaultManager] createFileAtPath:@"/etc/clutch_cracked.plist" contents:nil attributes:nil];
        dict = [[NSMutableDictionary alloc] init];
    }
    [dict setObject:version forKey: [infoplist objectForKey:@"CFBundleDisplayName"]];
    [dict writeToFile:@"/etc/clutch_cracked.plist" atomically:YES];
	[[NSFileManager defaultManager] removeItemAtPath:workingDir error:NULL];
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
        NSLog(@"DEBUG: 32bit portion detected %u", arch->cpusubtype);
        switch (arch->cpusubtype) {
            case ARMV7S_SUBTYPE:
                NSLog(@"DEBUG: armv7s portion detected");
                i = 11;
                break;
            case ARMV7_SUBTYPE:
                NSLog(@"DEBUG: armv7 portion detected");
                i = 9;
                break;
            case ARMV6_SUBTYPE:
                NSLog(@"DEBUG: armv6 portion detected");
                i = 6;
                break;
            default:
                NSLog(@"ERROR: unknown 32bit portion detected %u", arch->cpusubtype);
                i = -1;
                break;
        }
    }
    else if (arch->cputype == CPUTYPE_64) {
        switch (arch->cpusubtype) {
            case ARMV8_SUBTYPE:
                NSLog(@"DEBUG: armv8 portion detected! 64bit!!");
                i = 8;
                break;
            default:
                NSLog(@"ERROR: unknown 64bit portion detected");
                i = -1;
                break;
        }
    }
    return i;
}
NSString* swap_arch(NSString *binaryPath, NSString* baseDirectory, NSString* baseName, uint32_t swaparch) {    
    char swapBuffer[4096];
    if (local_arch == swaparch) {
        NSLog(@"UH HELLRO PLIS");
        return NULL;
    }
    
    NSString* suffix;
    
    switch (swaparch) {
        case ARMV7S_SUBTYPE:
            suffix = @"armv7s";
            break;
        case ARMV7_SUBTYPE:
            suffix = @"armv7";
            break;
        case ARMV6_SUBTYPE:
            suffix = @"armv6";
            break;
        case ARMV8_SUBTYPE:
            suffix= @"armv8";
            break;
    }
    
    NSString *orig_old_path = binaryPath; // save old binary path
    
    binaryPath = [binaryPath stringByAppendingFormat:@"_%@_lwork", suffix]; // new binary path
    [[NSFileManager defaultManager] copyItemAtPath:orig_old_path toPath:binaryPath error: NULL];
    
    FILE* swapbinary = fopen([binaryPath UTF8String], "r+");
    
    fseek(swapbinary, 0, SEEK_SET);
    fread(&swapBuffer, sizeof(swapBuffer), 1, swapbinary);
    struct fat_header* swapfh = (struct fat_header*) (swapBuffer);

    
    //moveItemAtPath:orig_old_path toPath:binaryPath error:NULL];
    // swap the architectures

    bool swap1 = FALSE, swap2 = FALSE;
    int i;
   
    
    struct fat_arch *swap_arch = (struct fat_arch *) &swapfh[1];
    
      NSLog(@"arch arch arch ok ok");
    
    for (i = CFSwapInt32(swapfh->nfat_arch); i--;) {
        if (CFSwapInt32(swap_arch->cpusubtype) == local_arch) {
            
            swap_arch->cpusubtype = swaparch;
            VERBOSE("swap: Found local arch");
            swap1 = TRUE;
        }
        
        else if (swap_arch->cpusubtype == swaparch) {
            switch (local_arch) {
                case ARMV7S:
                    swap_arch->cpusubtype = ARMV7S_SUBTYPE;
                    break;
                case ARMV7:
                    swap_arch->cpusubtype = ARMV7_SUBTYPE;
                    break;
                case ARMV6:
                    swap_arch->cpusubtype = ARMV6_SUBTYPE;
                    break;
                case ARMV8:
                    swap_arch->cpusubtype = ARMV8_SUBTYPE;
                    break;
            }
            VERBOSE("swap: swapped arch");
            swap2 = TRUE;
            
        }
        swap_arch++;
    }
    

    // move the SC_Info keys    
    NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
    sinf_file = [NSString stringWithFormat:@"%@_%@_lwork.sinf", scinfo_prefix, suffix];
    supp_file = [NSString stringWithFormat:@"%@_%@_lwork.supp", scinfo_prefix, suffix];
    NSLog(@"sinf file yo %@", sinf_file);
    [[NSFileManager defaultManager] moveItemAtPath:[scinfo_prefix stringByAppendingString:@".sinf"] toPath:sinf_file error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:[scinfo_prefix stringByAppendingString:@".supp"] toPath:supp_file error:NULL];

    if (swap1 && swap2) {
        VERBOSE("swap: Swapped both architectures");
    }
   
    fseek(swapbinary, 0, SEEK_SET);
    fwrite(swapBuffer, sizeof(swapBuffer), 1, swapbinary);
    VERBOSE("swap: Wrote new arch info");
    fclose(swapbinary);
    return binaryPath;

}
void swap_back(NSString *binaryPath, NSString* baseDirectory, NSString* baseName) {
    // remove swapped binary 
    [[NSFileManager defaultManager] removeItemAtPath:binaryPath error:NULL];
    //moveItemAtPath:binaryPath toPath:orig_old_path error:NULL];
    //move SC_Info back
    NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
    [[NSFileManager defaultManager] moveItemAtPath:sinf_file toPath:[scinfo_prefix stringByAppendingString:@".sinf"] error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:supp_file toPath:[scinfo_prefix stringByAppendingString:@".supp"] error:NULL];
    NSLog(@"DEBUG: Moving sinf_file %@ to %@", sinf_file, [scinfo_prefix stringByAppendingString:@".sinf"]);
}

NSString *crack_binary(NSString *binaryPath, NSString *finalPath, NSString **error) {
	[[NSFileManager defaultManager] copyItemAtPath:binaryPath toPath:finalPath error:NULL]; // move the original binary to that path
   	NSString *baseName = [binaryPath lastPathComponent]; // get the basename (name of the binary)
	NSString *baseDirectory = [NSString stringWithFormat:@"%@/", [binaryPath stringByDeletingLastPathComponent]]; // get the base directory
	
	// open streams from both files
	FILE *oldbinary, *newbinary;
    NSLog(@"DEBUG: binary path %@", binaryPath);
	oldbinary = fopen([binaryPath UTF8String], "r+");
	newbinary = fopen([finalPath UTF8String], "r+");
	
    fread(&buffer, sizeof(buffer), 1, oldbinary);
    fh = (struct fat_header*) (buffer);
        
    struct fat_arch armv6, armv7, armv7s, armv8, lipo;
    struct fat_arch *arch;
    
    int i;
    
    /* TESTING CODE FOR DUMPING INCLUDING STRIPPING
     * DON'T RELY ON THIS OR EXPECT IT TO WORK MA NIGGAS
     */
    
    NSLog(@"DEBUG: local cputype %u", get_local_cputype());
    
    if (fh->magic == FAT_CIGAM) {
        VERBOSE("binary is a fat executable");
        
        bool has_armv6 = FALSE;
        bool has_armv7 = FALSE;
        bool has_armv7s = FALSE;
        bool has_armv8 = FALSE;
        
        arch = (struct fat_arch *) &fh[1];
        
       // for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
        //apparently this is faster? I think so too.
        for (i = CFSwapInt32(fh->nfat_arch); i--;) {
            NSLog(@"DEBUG: cpusubtype %u %u", CFSwapInt32(arch->cpusubtype), CFSwapInt32(arch->cputype));
            NSLog(@"DEBUG: cpusubtype %u %u", arch->cpusubtype, arch->cputype);
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
                case 8:
                    armv8 = *arch;
                    has_armv8 = TRUE;
                    break;
                case -1:
                    *error = @"Unknown architecture detected.";
                    goto c_err;
                    break;
            }
            if ((local_cputype == CPUTYPE_32) && (CFSwapInt32(arch->cpusubtype) > local_arch)) {
                    NSLog(@"DEBUG: Can't crack arch %d on %d! skipping", CFSwapInt32(arch->cpusubtype), local_arch);
                    [stripHeaders addObject:[NSNumber numberWithUnsignedInt:arch->cpusubtype]];
            }
            else if (arch->cputype == CPUTYPE_64) {
                if ((local_cputype == CPUTYPE_64) && (arch->cpusubtype > local_arch)) {
                    NSLog(@"DEBUG: Can't crack 64bit arch %d on %d! skipping", CFSwapInt32(arch->cpusubtype), local_arch);
                    [stripHeaders addObject:[NSNumber numberWithUnsignedInt:arch->cpusubtype]];
                }
                else if (local_cputype == CPUTYPE_32) {
                    NSLog(@"DEBUG: can crack 64bit arch on this device! skipping");
                    [stripHeaders addObject:[NSNumber numberWithUnsignedInt:arch->cpusubtype]];
                }
            }
            /*else if ((arch->cpusubtype == ARMV8_SUBTYPE) && (local_arch != ARMV8)) {
                NSLog(@"DEBUG: Can't crack armv8 on non-armv8! skipping");
                [stripHeaders addObject:[NSNumber numberWithUnsignedInt:ARMV8_SUBTYPE]];
            }
            else if ((local_arch == ARMV6) && (CFSwapInt32(arch->cpusubtype) > ARMV6)) {
                NSLog(@"DEBUG: Can't crack >armv6 on armv6! skipping");
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
    
        
        NSLog(@"############################");
        NSLog(@"DEBUG: cpu_subtype: %u local_arch: %u\n", CFSwapInt32(arch->cpusubtype), local_arch);
        NSLog(@"DEBUG: offset: %u", CFSwapInt32(arch->offset));
        NSLog(@"############################");
        
        
        // Running on an armv7, armv7s, armv8, or higher device
        NSLog(@"DEBUG: path: %@", binaryPath);
        
        //fat binary
        NSLog(@"DEBUG: fat binary");
        arch = (struct fat_arch *) &fh[1];
        for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
            NSLog(@"DEBUG: Currently cracking arch %u", CFSwapInt32(arch->cpusubtype));
            if (local_arch != CFSwapInt32(arch->cpusubtype)) {
                if ([stripHeaders containsObject:[NSNumber numberWithUnsignedInt:arch->cpusubtype]]) {
                    NSLog(@"DEBUG: skipping");
                    arch++;
                    continue;
                }
                printf("swap: Currently cracking armv%u portion\n", CFSwapInt32(arch->cpusubtype));
                NSLog(@"DEBUG: cpusubtype isn't the same as local arch! swapping");
                NSString* newPath =  swap_arch(binaryPath, baseDirectory, baseName, arch->cpusubtype);
                NSLog(@"DEBUG: new path: %@", newPath);
                FILE* swapbinary = fopen([newPath UTF8String], "r+");
                if (!dump_binary(swapbinary, newbinary, CFSwapInt32(arch->offset), newPath)) {
                    // Dumping failed
                    stop_bar();
                    *error = @"Cannot crack swapped portion of binary.";
                    swap_back(newPath, baseDirectory, baseName);
                    goto c_err;
                }
                swap_back(newPath, baseDirectory, baseName);
            }
            else {
                if (!dump_binary(oldbinary, newbinary, CFSwapInt32(arch->offset), binaryPath)) {
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
        // Application is a thin binary
        VERBOSE("Application is a thin binary, cracking single architecture...");
        NOTIFY("Dumping binary...");
        
        if (!dump_binary(oldbinary, newbinary, 0, binaryPath)) {
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
        NSLog(@"fread sucessful!");
        for (int lc_index = 0; lc_index < mh.ncmds; lc_index++) {
            fread(&lc, sizeof(struct load_command), 1, newbinary);
            NSLog(@"loopy loopy %u", lc.cmd);
            if (lc-.cmd == LC_ENCRYPTION_INFO) {
                NSLog(@"LC_ENCRYPTION!!!!");
                fseek(newbinary, -1 * sizeof(struct load_command), SEEK_CUR);
                fread(&crypt, sizeof(struct encryption_info_command), 1, newbinary);
                if (crypt->cryptid == 0) {
                    NSLog(@"DEBUG: cryptid was patched!");
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
    NSLog(@"DEBUG: stripHeaders %@", stripHeaders);
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
            NSLog(@"DEBUG: loopy looopy %u", CFSwapInt32(arch->cpusubtype));
            NSLog(@"STIPHEADER: %d", [stripHeader unsignedIntValue]);
            fread(&doh, sizeof(struct fat_arch), 1, lipoOut);
            if (arch->cpusubtype == [stripHeader unsignedIntValue]) {
                NSLog(@"DEBUG: Found arch to strip! Storing it");
                if (i < CFSwapInt32(fh->nfat_arch)) {
                    fgetpos(lipoOut, &copypos);
                    NSLog(@"DEBUG: copy position %lld", copypos);
                }
                else {
                    NSLog(@"ERROR: Dunno where to store ler0-i09483430470374 help!!!!!");
                }
            }
            else if (i == (CFSwapInt32(fh->nfat_arch)) - 1) {
                copy = doh;
                fgetpos(lipoOut, &rempos);
                NSLog(@"DEBUG: remove position %lld", rempos);
            }
            arch++;
        }

        fh = (struct fat_header*) (stripBuffer);
        arch = (struct fat_arch *) &fh[1];
        for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
            if (arch->cpusubtype == [stripHeader unsignedIntValue])  {
                rempos = rempos - sizeof(struct fat_arch);
                fseek(lipoOut,rempos, SEEK_SET);
                NSLog(@"DEBUG: rempos %lld", rempos);
                char data[20];
                memset(data,'\0',sizeof(data));
                fwrite(data, sizeof(data), 1, lipoOut);
            }
            else if (i == (CFSwapInt32(fh->nfat_arch) - 1)) {
                copypos = copypos - sizeof(struct fat_arch);
                NSLog(@"DEBUG: copypos %lld", copypos);
                fseek(lipoOut, copypos, SEEK_SET);
                fwrite(&copy, sizeof(struct fat_arch), 1, lipoOut);
            }
            arch++;
        }
        
        NSLog(@"DEBUG: changing nfat_arch");
        uint32_t bin_nfat_arch;
        
        fseek(lipoOut, 4, SEEK_SET); //bin_magic
        fread(&bin_nfat_arch, 4, 1, lipoOut); // get the number of fat architectures in the file
        NSLog(@"DEBUG: number of architectures %u", CFSwapInt32(bin_nfat_arch));
        bin_nfat_arch = bin_nfat_arch - 0x1000000;
        
        NSLog(@"DEBUG: number of architectures %u", CFSwapInt32(bin_nfat_arch));
        fseek(lipoOut, 4, SEEK_SET); //bin_magic
        fwrite(&bin_nfat_arch, 4, 1, lipoOut);
        
        NSLog(@"DEBUG: Written new header to binary!");
        fclose(lipoOut);
        [[NSFileManager defaultManager] removeItemAtPath:finalPath error:NULL];
        [[NSFileManager defaultManager] moveItemAtPath:lipoPath toPath:finalPath error:NULL];

    }
    fclose(newbinary); // close the new binary stream
    fclose(oldbinary); // close the old binary stream
    return finalPath; // return  cracked binary path
	
c_lipo:
    NOTIFY("Can only crack one architecture!");
    NSLog(@"DEBUG: lipo offset %u", CFSwapInt32(lipo.offset));
    if (!dump_binary(oldbinary, newbinary, CFSwapInt32(lipo.offset), binaryPath)) {
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
    int value;
	int len = sizeof(value);
    sysctlbyname("hw.cpu64bit_capable", &value, (size_t *) &len, NULL, 0);
    NSLog(@"DEBUG: PROCESSOR VALUE %u", value);
    if (value != 0) {
        NSLog(@"DEBUG: 64bit processor!");
        return CPUTYPE_64;
    }
    else {
        NSLog(@"DEBUG: Not 64bit processor!");
        return CPUTYPE_32;
    }
}

int get_local_arch() {
	uint32_t i;
    //uint32_t sixtyfour;
	int len = sizeof(i);
	sysctlbyname("hw.cpusubtype", &i, (size_t *) &len, NULL, 0);
    if (i == 10) {
        i = 9;
        ios6 = TRUE;
    }
    /*sysctlbyname("hw.optional.64bitops", &sixtyfour, (size_t *) &len, NULL, 0);
    if (sixtyfour != 0) {
        NSLog(@"DEBUG: 64bit processor detected!");
        NSLog(@"DEBUG: hw.cpusubtype %u, hw.optional.64bitops %u", i, sixtyfour);
        i = 8;
    }*/
    //i = 11;
    NSLog(@"DEBUG: local arch %u %u", i,  CFSwapInt32(i));
	return i;
}
