#import "crack.h"

int overdrive_enabled = 0;
BOOL ios6 = FALSE;



NSString * crack_application(NSString *application_basedir, NSString *basename, NSString* version) {
    VERBOSE("Creating working directory...");
    stripHeaders = [[NSMutableArray alloc] init];
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
    NSString *addendum = @"";
    
    if (overdrive_enabled)
        addendum = @"-OD";
    
	NSString *ipapath;
	if ([[ClutchConfiguration getValue:@"FilenameCredit"] isEqualToString:@"YES"]) {
		ipapath = [NSString stringWithFormat:@"/var/root/Documents/Cracked/%@-v%@-%@%@.ipa", [[infoplist objectForKey:@"CFBundleDisplayName"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"], [infoplist objectForKey:@"CFBundleVersion"], crackerName, addendum];
	} else {
		ipapath = [NSString stringWithFormat:@"/var/root/Documents/Cracked/%@-v%@%@.ipa", [[infoplist objectForKey:@"CFBundleDisplayName"] stringByReplacingOccurrencesOfString:@"/" withString:@"_"], [infoplist objectForKey:@"CFBundleVersion"], addendum];
	}
	[[NSFileManager defaultManager] createDirectoryAtPath:@"/var/root/Documents/Cracked/" withIntermediateDirectories:TRUE attributes:nil error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:ipapath error:NULL];

	NSString *compressionArguments = [[ClutchConfiguration getValue:@"CompressionArguments"] stringByAppendingString:@" "];
	if (compressionArguments == nil)
		compressionArguments = @"";

    NOTIFY("Compressing first stage resources (1/2)...");
    
	system([[NSString stringWithFormat:@"cd %@; zip %@-m -r \"%@\" * 2>&1> /dev/null", workingDir, compressionArguments, ipapath] UTF8String]);
	[[NSFileManager defaultManager] moveItemAtPath:[workingDir stringByAppendingString:@"Payload"] toPath:[workingDir stringByAppendingString:@"Payload_1"] error:NULL];
    
    NOTIFY("Compressing second stage payload (2/2)...");
    
	[[NSFileManager defaultManager] createSymbolicLinkAtPath:[workingDir stringByAppendingString:@"Payload"] withDestinationPath:[application_basedir stringByAppendingString:@"/../"] error:NULL];
    
	system([[NSString stringWithFormat:@"cd %@; zip %@-u -y -r -n .jpg:.JPG:.jpeg:.png:.PNG:.gif:.GIF:.Z:.gz:.zip:.zoo:.arc:.lzh:.rar:.arj:.mp3:.mp4:.m4a:.m4v:.ogg:.ogv:.avi:.flac:.aac \"%@\" Payload/* -x Payload/iTunesArtwork Payload/iTunesMetadata.plist \"Payload/Documents/*\" \"Payload/Library/*\" \"Payload/tmp/*\" \"Payload/*/%@\" \"Payload/*/SC_Info/*\" 2>&1> /dev/null", workingDir, compressionArguments, ipapath, binary_name] UTF8String]);
	
    stop_bar();
    
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
    NSLog(@"FILE LOCCCCCCCCCC %@", baseDirectory);
    int local_arch = get_local_arch();
    if (local_arch == swaparch) {
        return NULL;
    }
    NSString *orig_old_path = binaryPath; // save old binary path
    //moveItemAtPath:orig_old_path toPath:binaryPath error:NULL];
    // swap the architectures
    
    struct fat_arch *arch = (struct fat_arch *) &fh[1];
    printf("Swapping architectures\n");
    bool swap1 = FALSE, swap2 = FALSE;
    int i;
    NSString* suffix;
    
    arch = (struct fat_arch *) &fh[1];
    for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
        if (CFSwapInt32(arch->cpusubtype) == local_arch) {
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
            arch->cpusubtype = swaparch;
            VERBOSE("swap: Found local arch");
            swap1 = TRUE;
        }
        
        else if (arch->cpusubtype == swaparch) {
            switch (local_arch) {
                case ARMV7S:
                    arch->cpusubtype = ARMV7S_SUBTYPE;
                    break;
                case ARMV7:
                    arch->cpusubtype = ARMV7_SUBTYPE;
                    break;
                case ARMV6:
                    arch->cpusubtype = ARMV6_SUBTYPE;
                    break;
                case ARMV8:
                    arch->cpusubtype = ARMV8_SUBTYPE;
                    break;
            }
            VERBOSE("found arch to swap, hmm");
            swap2 = TRUE;
            
        }
        arch++;
    }
    
    
    binaryPath = [binaryPath stringByAppendingFormat:@"_%@_lwork", suffix]; // new binary path
    [[NSFileManager defaultManager] copyItemAtPath:orig_old_path toPath:binaryPath error: NULL];

    // move the SC_Info keys    
    NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
    sinf_file = [NSString stringWithFormat:@"%@_%@_lwork.sinf", scinfo_prefix, suffix];
    supp_file = [NSString stringWithFormat:@"%@_%@_lwork.supp", scinfo_prefix, suffix];
    NSLog(@"sinf file yo %@", sinf_file);
    [[NSFileManager defaultManager] moveItemAtPath:[scinfo_prefix stringByAppendingString:@".sinf"] toPath:sinf_file error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:[scinfo_prefix stringByAppendingString:@".supp"] toPath:supp_file error:NULL];

    printf("ARCH COUNT %u", i);
    if (swap1 && swap2) {
        VERBOSE("swapped both architectures");
    }
    FILE* swapbinary = fopen([binaryPath UTF8String], "r+");
    fseek(swapbinary, 0, SEEK_SET);
    fwrite(buffer, sizeof(buffer), 1, swapbinary);
    VERBOSE("wrote new arch info");
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
    int local_arch = get_local_arch(); // get the local architecture
   	NSString *baseName = [binaryPath lastPathComponent]; // get the basename (name of the binary)
	NSString *baseDirectory = [NSString stringWithFormat:@"%@/", [binaryPath stringByDeletingLastPathComponent]]; // get the base directory
	
	// open streams from both files
	FILE *oldbinary, *newbinary;
    NSLog(@"DEBUG: binary path %@", binaryPath);
	oldbinary = fopen([binaryPath UTF8String], "r+");
	newbinary = fopen([finalPath UTF8String], "r+");
	
    fread(&buffer, sizeof(buffer), 1, oldbinary);
    fh = (struct fat_header*) (buffer);
        
    struct fat_arch armv6, armv7, armv7s, armv8;
    struct fat_arch *arch;
    
    int i;
    
    /* TESTING CODE FOR DUMPING INCLUDING STRIPPING
     * DON'T RELY ON THIS OR EXPECT IT TO WORK MA NIGGAS
     */
    
    
    if (fh->magic == FAT_CIGAM) {
        VERBOSE("binary is a fat executable");
        
        bool has_armv6 = FALSE;
        bool has_armv7 = FALSE;
        bool has_armv7s = FALSE;
        bool has_armv8 = FALSE;
        
        arch = (struct fat_arch *) &fh[1];        
        for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
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
        }

        arch = (struct fat_arch *) &fh[1];
        
        NSLog(@"############################");
        NSLog(@"DEBUG: cpu_subtype: %u local_arch: %u\n", CFSwapInt32(arch->cpusubtype), local_arch);
        NSLog(@"DEBUG: offset: %u", CFSwapInt32(arch->offset));
        NSLog(@"############################");
        
        if (local_arch > ARMV6) {
            // Running on an armv7, armv7s, armv8, or higher device
            NSLog(@"DEBUG: path: %@", binaryPath);

            if (CFSwapInt32(fh->nfat_arch) > 1) {
                //fat binary
                NSLog(@"DEBUG: fat binary");
                arch = (struct fat_arch *) &fh[1];
                for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
                    NSLog(@"DEBUG: Currently cracking arch %u", CFSwapInt32(arch->cpusubtype));
                    if (local_arch != CFSwapInt32(arch->cpusubtype)) {
                        if ((arch->cpusubtype == ARMV7S_SUBTYPE) && (local_arch != ARMV7S)) {
                            NSLog(@"DEBUG: Can't crack armv7s on non-armv7s! skipping");
                            [stripHeaders addObject:[NSNumber numberWithUnsignedInt:ARMV7S_SUBTYPE]];
                            arch++;
                            continue;
                        }
                        else if ((arch->cpusubtype == ARMV8_SUBTYPE) && (local_arch != ARMV8)) {
                            NSLog(@"DEBUG: Can't crack armv8 on non-armv8! skipping");
                            [stripHeaders addObject:[NSNumber numberWithUnsignedInt:ARMV8_SUBTYPE]];
                            arch++;
                            continue;
                        }
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
                if (has_armv7s && has_armv7 && (local_arch != ARMV7S)) {
                    NSLog(@"DEBUG: Cannot crack armv7s portion, lipo");
                    NSLog(@"DEBUG: armv7 offset %u", CFSwapInt32(armv7.offset));
                    if (!dump_binary(oldbinary, newbinary, CFSwapInt32(armv7.offset), binaryPath)) {
                        // Dumping failed
                        stop_bar();
                        *error = @"Cannot crack ARMV7 portion.";
                        goto c_err;
                    }
                    stop_bar();
                    
                    NSLog(@"DEBUG: Performing liposuction of ARMV7 mach object...");
                    
                    // Lipo out the data
                    NSString *lipoPath = [NSString stringWithFormat:@"%@_l", finalPath]; // assign a new lipo path
                    FILE *lipoOut = fopen([lipoPath UTF8String], "w+"); // prepare the file stream
                    fseek(newbinary, CFSwapInt32(armv7.offset), SEEK_SET); // go to the armv6 offset
                    void *tmp_b = malloc(0x1000); // allocate a temporary buffer
                    
                    uint32_t remain = CFSwapInt32(armv7.size);
                    
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
                }
                
            }
        }
        //fat + armv6
        else if (local_arch == ARMV6) {
            // Can only crack ARMV6 binaries because we have a shitty device :(
            
            VERBOSE("Application is a fat binary, only cracking ARMV6 portion (we are on an ARMV6 device)...");
            
            if (!dump_binary(oldbinary, newbinary, CFSwapInt32(armv6.offset), binaryPath)) {
                // Dumping failed
                stop_bar();
                *error = @"Cannot crack ARMV6 portion.";
                goto c_err;
            }
            
            stop_bar();
            
            VERBOSE("Performing liposuction of ARMV6 mach object...");
            
            // Lipo out the data
            NSString *lipoPath = [NSString stringWithFormat:@"%@_l", finalPath]; // assign a new lipo path
            FILE *lipoOut = fopen([lipoPath UTF8String], "w+"); // prepare the file stream
            fseek(newbinary, CFSwapInt32(armv6.offset), SEEK_SET); // go to the armv6 offset
            void *tmp_b = malloc(0x1000); // allocate a temporary buffer
            
            uint32_t remain = CFSwapInt32(armv6.size);
            
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
        }
    }
    
    //thin binary
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
    }

    //9 11 6
    struct fat_arch copy, doh;
    fpos_t copypos, rempos;
    uint32_t stripHeader;
    for (id item in stripHeaders) {
        stripHeader = (uint32_t) item;
        NSLog(@"######### STRIP HEADER STRIP STRIP STRIP STRIP ############");
        NSString *lipoPath = [NSString stringWithFormat:@"%@_l", finalPath]; // assign a new lipo path
        [[NSFileManager defaultManager] copyItemAtPath:finalPath toPath:lipoPath error: NULL];
        FILE *lipoOut = fopen([lipoPath UTF8String], "r+"); // prepare the file stream
        char stripBuffer[4096];
        fseek(lipoOut, SEEK_SET, 0);
        fread(&stripBuffer, sizeof(buffer), 1, lipoOut);
        fh = (struct fat_header*) (stripBuffer);
        arch = (struct fat_arch *) &fh[1];
        
        fseek(lipoOut, 8, SEEK_SET); //skip nfat_arch and bin_magic
        NSLog(@"DEBUG: Stripping headers");
        
        
        for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
            NSLog(@"DEBUG: loopy looopy %u", CFSwapInt32(arch->cpusubtype));
            fread(&doh, sizeof(struct fat_arch), 1, lipoOut);
            if (arch->cpusubtype == stripHeader) {
                NSLog(@"DEBUG: Found arch to strip! Storing it");
                if (i < CFSwapInt32(fh->nfat_arch)) {
                    NSLog(@"DEBUG: TEST TEST 2130");
                    fgetpos(lipoOut, &copypos);
                    NSLog(@"DEBUG: FROMPOS %lld", copypos);
                }
                else {
                    NSLog(@"ERROR: Dunno where to store ler0-i09483430470374 help!!!!!");
                }
            }
            else if (i == (CFSwapInt32(fh->nfat_arch)) - 1) {
                copy = doh;
                fgetpos(lipoOut, &rempos);
                NSLog(@"DEBUG: TOPOS %lld", rempos);
            }
            arch++;
        }
        fh = (struct fat_header*) (stripBuffer);
        arch = (struct fat_arch *) &fh[1];
        for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
            if (arch->cpusubtype == stripHeader)  {
                rempos = rempos - sizeof(struct fat_arch);
                fseek(lipoOut,rempos, SEEK_SET);
                NSLog(@"DEBUG: rempos %lld", rempos);
                NSLog(@"DEBUG: Writing nulls to unwanted arch swag swag 2");
                char data[20];
                memset(data,'\0',sizeof(data));
                fwrite(data, sizeof(data), 1, lipoOut);
                
                NSLog(@"DEBUG: Written nulls to unwanted arch swag swag swag 3");
            }
            else if (i == (CFSwapInt32(fh->nfat_arch) - 1)) {
                copypos = copypos - sizeof(struct fat_arch);
                NSLog(@"DEBUG: copypos %lld", copypos);
                fseek(lipoOut, copypos, SEEK_SET);
                fwrite(&copy, sizeof(struct fat_arch), 1, lipoOut);
                NSLog(@"DEBUG: Written arch swap swap swap 1");
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

int get_local_arch() {
	int i, sixtyfour;
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
	return i;
}
