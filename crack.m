#import "crack.h"

/*
* lipo.c  
* Copyright (c) 1999 Apple Computer, Inc. All rights reserved.
*
* @APPLE_LICENSE_HEADER_START@
*
* This file contains Original Code and/or Modifications of Original Code
    * as defined in and that are subject to the Apple Public Source License
    * Version 2.0 (the 'License'). You may not use this file except in
    * compliance with the License. Please obtain a copy of the License at
    * http://www.opensource.apple.com/apsl/ and read it before using this
    * file.
    *
    * The Original Code and all software distributed under the License are
    * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
    * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
        * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
    * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
    * Please see the License for the specific language governing rights and
    * limitations under the License.
    *
    * @APPLE_LICENSE_HEADER_END@
*/



int overdrive_enabled = 0;


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

NSString* swap_arch(NSString *binaryPath, NSString* baseDirectory, NSString* baseName, uint32_t swaparch) {
    NSLog(@"FILE LOCCCCCCCCCC %@", baseDirectory);
    int local_arch = get_local_arch();
    if (local_arch == swaparch) {
        return NULL;
    }
    NSString *orig_old_path = binaryPath; // save old binary path
    binaryPath = [binaryPath stringByAppendingString:@"_lwork"]; // new binary path
    [[NSFileManager defaultManager] copyItemAtPath:orig_old_path toPath:binaryPath error: NULL];
    //moveItemAtPath:orig_old_path toPath:binaryPath error:NULL];

    FILE* oldbinary = fopen([binaryPath UTF8String], "r+");
    
    // move the SC_Info keys
    
    NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
    
    [[NSFileManager defaultManager] moveItemAtPath:[scinfo_prefix stringByAppendingString:@".sinf"] toPath:[scinfo_prefix stringByAppendingString:@"_lwork.sinf"] error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:[scinfo_prefix stringByAppendingString:@".supp"] toPath:[scinfo_prefix stringByAppendingString:@"_lwork.supp"] error:NULL];
    
    // swap the architectures
    
    struct fat_arch *arch = (struct fat_arch *) &fh[1];
    printf("Swapping architectures\n");
    bool swap1 = FALSE, swap2 = FALSE;
    int i;
    
    arch = (struct fat_arch *) &fh[1];
    for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
        if (CFSwapInt32(arch->cpusubtype) == local_arch) {
            switch (swaparch) {
                case ARMV7S:
                    arch->cpusubtype = ARMV7S_SUBTYPE;
                    break;
                case ARMV7:
                    arch->cpusubtype = ARMV7_SUBTYPE;
                    break;
                case ARMV6:
                    arch->cpusubtype = ARMV6_SUBTYPE;
                    break;
            }
            VERBOSE("found local arch");
            swap1 = TRUE;
        }
        else if (CFSwapInt32(arch->cpusubtype) == swaparch) {
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
            }
            VERBOSE("found arch to swap, hmm");
            swap2 = TRUE;
            
        }
        arch++;
    }
    printf("ARCH COUNT %u", i);
    if (swap1 && swap2) {
        VERBOSE("swapped both architectures");
    }
    
    fseek(oldbinary, 0, SEEK_SET);
    fwrite(buffer, sizeof(buffer), 1, oldbinary);
    VERBOSE("wrote new arch info");
    fclose(oldbinary);
    return binaryPath;

}
void swap_back(NSString *binaryPath, NSString* baseDirectory, NSString* baseName) {
    // move the binary and SC_Info keys back
    [[NSFileManager defaultManager] removeItemAtPath:binaryPath error:NULL];
    //moveItemAtPath:binaryPath toPath:orig_old_path error:NULL];
    NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
    [[NSFileManager defaultManager] moveItemAtPath:[scinfo_prefix stringByAppendingString:@"_lwork.sinf"] toPath:[scinfo_prefix stringByAppendingString:@".sinf"] error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:[scinfo_prefix stringByAppendingString:@"_lwork.supp"] toPath:[scinfo_prefix stringByAppendingString:@".supp"] error:NULL];
}

NSString * crack_binary(NSString *binaryPath, NSString *finalPath, NSString **error) {
    int local_arch = get_local_arch(); // get the local architecture
    
	[[NSFileManager defaultManager] copyItemAtPath:binaryPath toPath:finalPath error:NULL]; // move the original binary to that path
	NSString *baseName = [binaryPath lastPathComponent]; // get the basename (name of the binary)
	NSString *baseDirectory = [NSString stringWithFormat:@"%@/", [binaryPath stringByDeletingLastPathComponent]]; // get the base directory
	
	// open streams from both files
	FILE *oldbinary, *newbinary, *backupold;
	oldbinary = fopen([binaryPath UTF8String], "r+");
	newbinary = fopen([finalPath UTF8String], "r+");
	
    
	// the first four bytes are the magic which defines whether the binary is fat or not
	//uint32_t bin_magic;
	//fread(&bin_magic, 4, 1, oldbinary);
	//fseek(oldbinary, 0, SEEK_SET);
    fread(&buffer, sizeof(buffer), 1, oldbinary);
    
    fh = (struct fat_header*) (buffer);
        
    struct fat_arch armv6, armv7, armv7s;
    
    

    /* TESTING CODE FOR DUMPING INCLUDING STRIPPING
     * DON'T RELY ON THIS OR EXPECT IT TO WORK MA NIGGAS
     */
    
    
    if (fh->magic == FAT_CIGAM) {
        VERBOSE("binary is a fat executable");
        
        bool has_armv6 = FALSE;
        bool has_armv7 = FALSE;
        bool has_armv7s = FALSE;
        
        
        struct fat_arch *arch;
        arch = (struct fat_arch *) &fh[1];
        int i;
        int archcount = 0;
        
        for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
            if (CFSwapInt32(arch->cpusubtype) == ARMV7S) {
                printf("Cool looks like this is an iPhone 5 binary!\n");
                if (local_arch != ARMV7S) {
                    printf("hmmm looks like we can't crack it, #noswag.\n");
                    stripHeader = TRUE;
                    int n_arch = CFSwapInt32(fh->nfat_arch);
                    n_arch--;
                    lipo_offset =  sizeof(struct fat_header) + n_arch * sizeof(struct fat_arch);
                }
            }
            arch++;
        }
        
        if (local_arch > ARMV6) {
            // Running on an armv7, armv7s, or higher device
            NSLog(@"cool swag %@", binaryPath);
            for (i = 0; i < CFSwapInt32(fh->nfat_arch); i++) {
                BOOL swap = FALSE;
                // iterate through the amount of arch types found
                if (CFSwapInt32(arch->cpusubtype) == ARMV6) {
                    // ARMV6 portion found
                    armv6 = *arch;
                    offset = armv6.offset;
                    if (stripHeader) {
                        lipo_offset+= armv6.size;
                        armv6.offset = lipo_offset;
                    }
                    if (local_arch != ARMV6) {
                        // are we not an ARMV6 device
                        backupold = oldbinary;
                        printf("SWAPPING ARMV6 #$######## YOLO\n");
                        NSString* newPath =  swap_arch(binaryPath, baseDirectory, baseName, ARMV6);
                        FILE* swapbinary = fopen([newPath UTF8String], "r+");
                        swap = TRUE;
                        if (!dump_binary(swapbinary, newbinary, CFSwapInt32(offset), newPath)) {
                            // Dumping failed
                            stop_bar();
                            *error = @"Cannot crack ARMV6 portion of binary.";
                            goto c_err;
                        }
                        swap_back(newPath, baseDirectory, baseName);
                    
                    }
                    else {
                        if (!dump_binary(oldbinary, newbinary, CFSwapInt32(offset), binaryPath)) {
                            // Dumping failed
                            stop_bar();
                            *error = @"Cannot crack ARMV6 portion of binary.";
                            goto c_err;
                        }
                    }
                    archcount++;
                    VERBOSE("found armv6");
                    has_armv6 = TRUE;
                    
                } else if (CFSwapInt32(arch->cpusubtype) == ARMV7) {
                    // ARMV7 portion found
                    printf("HUHHHHHHHHHHH YOLO SWAG %u SSSSS %u\n", CFSwapInt32(arch->cpusubtype), local_arch);
                    armv7 = *arch;
                    offset = armv7.offset;
                    if (stripHeader) {
                        lipo_offset+= armv6.size;
                        armv7.offset = lipo_offset;
                    }
                    if (local_arch != ARMV7) {
                        printf("SWAPPING SOMETHING TO ARMV7 HUHHHH ????? #$######## YOLO\n");
                        NSString* newPath =  swap_arch(binaryPath, baseDirectory, baseName, ARMV6);
                        FILE* swapbinary = fopen([newPath UTF8String], "r+");
                        if (!dump_binary(swapbinary, newbinary, CFSwapInt32(offset), newPath)) {
                            // Dumping failed
                            stop_bar();
                            *error = @"Cannot crack ARMV7 portion of binary.";
                            goto c_err;
                        }
                        swap_back(newPath, baseDirectory, baseName);
                    }
                    else {
                         printf("HELLLLO POLIS DUmping armv7 $$$$$$$$##O$#)_$*()#(*$) iTWORKED???\n");
                        NSLog(@"swag of the century %@ %u", binaryPath, CFSwapInt32(offset));
                        if (!dump_binary(oldbinary, newbinary, 4096, binaryPath)) {
                            // Dumping failed
                            stop_bar();
                            *error = @"Cannot crack ARMV7 portion of binary.";
                            goto c_err;
                        }
                    }
                    archcount++;
                    VERBOSE("found armv7");
                    has_armv7 = TRUE;
                } else if (CFSwapInt32(arch->cpusubtype) == ARMV7S) {
                    // ARMV7S portion found
                    if (local_arch != ARMV7S) {
                        // On a non-armv7s device {armv6 || armv7}
                        // We cannot crack this and need to strip the headers
                        //stripHeader = 1;
                        VERBOSE("found armv7s but cannot crack it on this device");
                    } else {
                        // On an armv7s device
                        if (!dump_binary(oldbinary, newbinary, CFSwapInt32(armv7s.offset), binaryPath)) {
                            // Dumping failed
                            stop_bar();
                            *error = @"Cannot crack ARMV7S portion of binary.";
                            goto c_err;
                        }
                        
                        armv7s = *arch;
                        VERBOSE("found armv7s");
                        has_armv7s = TRUE;

                    }
                    
                    archcount++;
                }
                
                arch++;
            }
            
            if (archcount != CFSwapInt32(fh->nfat_arch)) {
                // Found an incorrect amount of architectures - bailin'
                *error = @"Could not find correct architectures";
                goto c_err;
            }
        
        }
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

    
#warning strip binaries here - or move off to a seperate thinggiemagig?
    
    
    if (stripHeader) {
        printf("stripping headers yo\n");
        //create new headers
        struct fat_header *newheader;
        newheader->nfat_arch = fh->nfat_arch;
        newheader->nfat_arch--;
        newheader->magic = FAT_MAGIC;
        
        fseek(newbinary, 0, SEEK_SET);
        //write the header information
        fwrite(newheader, sizeof(struct fat_header), 1, newbinary);
        printf("Wrote new header info\n");
        //write the individual arch
        if (armv6.offset > armv7.offset) {
            fwrite(&armv7, sizeof(struct fat_arch), 1, newbinary);
            fwrite(&armv6, sizeof(struct fat_arch), 1, newbinary);
        }
        else {
            fwrite(&armv6, sizeof(struct fat_arch), 1, newbinary);
            fwrite(&armv7, sizeof(struct fat_arch), 1, newbinary);
        }
        
        VERBOSE("wrote new earch information");
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
	int i;
	int len = sizeof(i);
	sysctlbyname("hw.cpusubtype", &i, (size_t *) &len, NULL, 0);
    if (i == 10) {
        i = 9;
        //??? yolo
    }
    //i = 11;
    printf("SWAg pls %u", i);
	return i;
}
