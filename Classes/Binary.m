#import "Binary.h"
#import "Device.h"
#import "sha1.h"
#import "Localization.h"
#import <sys/stat.h>
#import "Constants.h"

#define local_arch [Device cpu_subtype]

#define local_cputype [Device cpu_type]

#define iOS5 1

@interface Binary ()
{
	NSString *oldbinaryPath;
	FILE* oldbinary;
    
	NSString *newbinaryPath;
	FILE* newbinary;
    
	BOOL credit;
	NSString *OVERDRIVE_DYLIB_PATH;
    
	NSString* sinfPath;
	NSString* suppPath;
	NSString* supfPath;
}
@end

@implementation Binary

- (id)init
{
	return nil;
}

-(void)patchPIE:(BOOL)patch {
    self->patchPIE = patch;
}

-(NSString *) genRandStringLength: (int) len
{
	NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	NSMutableString *randomString = [NSMutableString stringWithCapacity: len];
    
	for (int i=0; i<len; i++)
	{
		[randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
	}
    
	return randomString;
}

- (id)initWithBinary:(NSString *)thePath
{
    
	if (![NSFileManager.defaultManager fileExistsAtPath:thePath])
	{
		return nil;
	}
    
	if (self = [super init])
	{
		oldbinaryPath = thePath;
		overdriveEnabled = NO;
		credit = [[Preferences sharedInstance] creditFile];
        
		NSMutableCharacterSet *charactersToRemove = [NSMutableCharacterSet alphanumericCharacterSet];
        
		[charactersToRemove formUnionWithCharacterSet:[NSMutableCharacterSet nonBaseCharacterSet]];
        
		NSCharacterSet *charactersToRemove1 = [charactersToRemove invertedSet];
        
		NSString *trimmedReplacement =
			[[[[Preferences sharedInstance] crackerName] componentsSeparatedByCharactersInSet:charactersToRemove1]
				componentsJoinedByString:@""];
        
		OVERDRIVE_DYLIB_PATH = [[NSString alloc]initWithFormat:@"@executable_path/%@.dylib",credit? trimmedReplacement : @"overdrive"]; //credit protection FTW
	}
    
	return self;
}

-(NSString *)readable_cputype:(cpu_type_t)type
{
	NSString *_cputype = @"unknown";
    
	if (type == CPU_TYPE_ARM) {
		_cputype = @"arm";
	}
	else if (type == CPU_TYPE_ARM64)
	{
		_cputype = @"arm64";
        
	}
    
	return _cputype;
}

-(NSString *)readable_cpusubtype:(cpu_subtype_t)subtype
{
    
	NSString *_cpusubtype = @"unknown";
    
	switch (subtype)
	{
		case CPU_SUBTYPE_ARM_V7S:
		_cpusubtype = @"armv7s";
		break;
            
		case CPU_SUBTYPE_ARM_V7:
		_cpusubtype = @"armv7";
		break;
		case CPU_SUBTYPE_ARM_V6:
		_cpusubtype = @"armv6";
		break;
		case CPU_SUBTYPE_ARM64_V8:
		_cpusubtype = @"armv8";
		break;
		case CPU_SUBTYPE_ARM64_ALL:
		_cpusubtype = @"arm64";
		break;
	}
    
	return _cpusubtype;
}

- (NSString *)stripArch:(cpu_subtype_t)keep_arch
{
	NSString *baseName = [oldbinaryPath lastPathComponent]; // get the basename (name of the binary)
	NSString *baseDirectory = [NSString stringWithFormat:@"%@/", [oldbinaryPath stringByDeletingLastPathComponent]];
    
	DEBUG(@"##### STRIPPING ARCH #####");
    
	NSString* suffix = [NSString stringWithFormat:@"arm%u_lwork", CFSwapInt32(keep_arch)];
	NSString *lipoPath = [NSString stringWithFormat:@"%@_%@", oldbinaryPath, suffix]; // assign a new lipo path
    
	DEBUG(@"lipo path %s", [lipoPath UTF8String]);
    
	[[NSFileManager defaultManager] copyItemAtPath:oldbinaryPath toPath:lipoPath error: NULL];
    
	FILE *lipoOut = fopen([lipoPath UTF8String], "r+"); // prepare the file stream
	char stripBuffer[4096];
    
	fseek(lipoOut, SEEK_SET, 0);
	fread(&stripBuffer, sizeof(buffer), 1, lipoOut);
    
	struct fat_header* fh = (struct fat_header*) (stripBuffer);
	struct fat_arch* arch = (struct fat_arch *) &fh[1];
	struct fat_arch copy;
    
	BOOL foundarch = FALSE;
    
	fseek(lipoOut, 8, SEEK_SET); //skip nfat_arch and bin_magic
    
	for (int i = 0; i < CFSwapInt32(fh->nfat_arch); i++)
	{
		if (arch->cpusubtype == keep_arch)
		{
			DEBUG(@"found arch to keep %u! Storing it", CFSwapInt32(keep_arch));
			foundarch = TRUE;
        
			fread(&copy, sizeof(struct fat_arch), 1, lipoOut);
		}
		else
		{
			fseek(lipoOut, sizeof(struct fat_arch), SEEK_CUR);
		}
        
		arch++;
	}
    
	if (!foundarch)
	{
		DEBUG(@"error: could not find arch to keep!");
		return false;
	}
    
	fseek(lipoOut, 8, SEEK_SET);
	fwrite(&copy, sizeof(struct fat_arch), 1, lipoOut);
    
	char data[20];
    
	memset(data,'\0',sizeof(data));
    
	for (int i = 0; i < (CFSwapInt32(fh->nfat_arch) - 1); i++)
	{
		DEBUG(@"blanking arch! %u", i);
		fwrite(data, sizeof(data), 1, lipoOut);
	}
    
	//change nfat_arch
	DEBUG(@"changing nfat_arch");
    
	uint32_t bin_nfat_arch = 0x1000000;
    
	DEBUG(@"number of architectures %u", CFSwapInt32(bin_nfat_arch));
    
	fseek(lipoOut, 4, SEEK_SET); //bin_magic
	fwrite(&bin_nfat_arch, 4, 1, lipoOut);
    
	DEBUG(@"Wrote new header to binary!");
    
	fclose(lipoOut);
    
	DEBUG(@"copying sc_info files!");
    
	NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
	sinfPath = [NSString stringWithFormat:@"%@_%@.sinf", scinfo_prefix, suffix];
	suppPath = [NSString stringWithFormat:@"%@_%@.supp", scinfo_prefix, suffix];
	supfPath = [NSString stringWithFormat:@"%@_%@.supf", scinfo_prefix, suffix];
    
	if ([[NSFileManager defaultManager] fileExistsAtPath:[scinfo_prefix stringByAppendingString:@".supf"]])
	{
		[[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".supf"] toPath:supfPath error:NULL];
	}
    
	NSLog(@"sinf file yo %@", sinfPath);
    
	[[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".sinf"] toPath:sinfPath error:NULL];
	[[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".supp"] toPath:suppPath error:NULL];
    
	return lipoPath;
}

- (BOOL) removeArchitecture:(struct fat_arch*) removeArch
{
	fpos_t upperArchpos = 0, lowerArchpos = 0;
	char archBuffer[20];
    
	NSString *lipoPath = [NSString stringWithFormat:@"%@_%@_l", newbinaryPath,[self readable_cpusubtype:CFSwapInt32(removeArch->cpusubtype)]]; // assign a new lipo path
    
	[[NSFileManager defaultManager] copyItemAtPath:newbinaryPath toPath:lipoPath error: NULL];
    
	FILE *lipoOut = fopen([lipoPath UTF8String], "r+"); // prepare the file stream
	char stripBuffer[4096];
	fseek(lipoOut, SEEK_SET, 0);
	fread(&stripBuffer, sizeof(buffer), 1, lipoOut);
    
	struct fat_header* fh = (struct fat_header*) (stripBuffer);
	struct fat_arch* arch = (struct fat_arch *) &fh[1];
    
	fseek(lipoOut, 8, SEEK_SET); //skip nfat_arch and bin_magic
	BOOL strip_is_last = false;
    
	DEBUG(@"searching for copyindex");
    
	for (int i = 0; i < CFSwapInt32(fh->nfat_arch); i++)
	{
		DEBUG(@"index %u, nfat_arch %u", i, CFSwapInt32(fh->nfat_arch));
		if (CFSwapInt32(arch->cpusubtype) == CFSwapInt32(removeArch->cpusubtype))
		{
            
			DEBUG(@"found the upperArch we want to remove!");
			fgetpos(lipoOut, &upperArchpos);
            
			//check the index of the arch to remove
			if ((i+1) == CFSwapInt32(fh->nfat_arch))
			{
				//it's at the bottom
				DEBUG(@"at the bottom!! capitalist scums");
				strip_is_last = true;
			}
			else
			{
				DEBUG(@"hola");
			}
		}
        
		fseek(lipoOut, sizeof(struct fat_arch), SEEK_CUR);
        
		arch++;
	}
    
	if (!strip_is_last)
	{
		DEBUG(@"strip is not last!")
			fseek(lipoOut, 8, SEEK_SET); //skip nfat_arch and bin_magic! reset yo
		arch = (struct fat_arch *) &fh[1];
        
		for (int i = 0; i < CFSwapInt32(fh->nfat_arch); i++)
		{
			//swap the one we want to strip with the next one below it
			DEBUG(@"## iterating archs %u removearch:%u", CFSwapInt32(arch->cpusubtype), CFSwapInt32(removeArch->cpusubtype));
			if (i == (CFSwapInt32(fh->nfat_arch)) - 1)
			{
				DEBUG(@"found the lowerArch we want to copy!");
				fgetpos(lipoOut, &lowerArchpos);
			}
            
			fseek(lipoOut, sizeof(struct fat_arch), SEEK_CUR);
            
			arch++;
		}
        
		if ((upperArchpos == 0) || (lowerArchpos == 0))
		{
			ERROR(@"could not find swap swap swap!");
			return false;
		}
        
		//go to the lower arch location
		fseek(lipoOut, lowerArchpos, SEEK_SET);
		fread(&archBuffer, sizeof(archBuffer), 1, lipoOut);
        
		DEBUG(@"upperArchpos %lld, lowerArchpos %lld", upperArchpos, lowerArchpos);
        
		//write the lower arch data to the upper arch poistion
		fseek(lipoOut, upperArchpos, SEEK_SET);
		fwrite(&archBuffer, sizeof(archBuffer), 1, lipoOut);
       
		//blank the lower arch position
		fseek(lipoOut, lowerArchpos, SEEK_SET);
	}
	else
	{
		fseek(lipoOut, upperArchpos, SEEK_SET);
	}
    
	memset(archBuffer,'\0',sizeof(archBuffer));
	fwrite(&archBuffer, sizeof(archBuffer), 1, lipoOut);
    
	//change nfat_arch
	uint32_t bin_nfat_arch;
    
	fseek(lipoOut, 4, SEEK_SET); //bin_magic
	fread(&bin_nfat_arch, 4, 1, lipoOut); // get the number of fat architectures in the file
    
	DEBUG(@"number of architectures %u", CFSwapInt32(bin_nfat_arch));
    
	bin_nfat_arch = bin_nfat_arch - 0x1000000;
    
	DEBUG(@"number of architectures %u", CFSwapInt32(bin_nfat_arch));
    
	fseek(lipoOut, 4, SEEK_SET); //bin_magic
	fwrite(&bin_nfat_arch, 4, 1, lipoOut);
    
	DEBUG(@"Written new header to binary!");
    
	fclose(lipoOut);
    
	[[NSFileManager defaultManager] removeItemAtPath:newbinaryPath error:NULL];
	[[NSFileManager defaultManager] moveItemAtPath:lipoPath toPath:newbinaryPath error:NULL];
    
	return true;
}

-(BOOL) lipoBinary:(struct fat_arch*) arch
{
	// Lipo out the data
	NSString *lipoPath = [NSString stringWithFormat:@"%@_l", newbinaryPath]; // assign a new lipo path
    
	FILE *lipoOut = fopen([lipoPath UTF8String], "w+"); // prepare the file stream
	fseek(newbinary, CFSwapInt32(arch->offset), SEEK_SET); // go to the armv6 offset
    
	void *tmp_b = malloc(0x1000); // allocate a temporary buffer
    
	NSUInteger remain = CFSwapInt32(arch->size);
    
	while (remain > 0)
	{
		if (remain > 0x1000)
		{
			// move over 0x1000
			fread(tmp_b, 0x1000, 1, newbinary);
			fwrite(tmp_b, 0x1000, 1, lipoOut);
			remain -= 0x1000;
		} else
		{
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
    
	[[NSFileManager defaultManager] removeItemAtPath:newbinaryPath error:NULL]; // remove old file
	[[NSFileManager defaultManager] moveItemAtPath:lipoPath toPath:newbinaryPath error:NULL]; // move the lipo'd binary to the final path
    
	chown([newbinaryPath UTF8String], 501, 501); // adjust permissions
	chmod([newbinaryPath UTF8String], 0777); // adjust permissions
    
	return true;
}


- (BOOL)crackBinaryToFile:(NSString *)finalPath error:(NSError * __autoreleasing *)error
{
	newbinaryPath = finalPath;
	DEBUG(@"attempting to crack binary to file! finalpath %@", finalPath);
	DEBUG(@"DEBUG: binary path %@", oldbinaryPath);
    
	if (![[NSFileManager defaultManager] copyItemAtPath:oldbinaryPath toPath:finalPath error:NULL])
	{
        if (![[NSFileManager defaultManager] createDirectoryAtPath:[finalPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil])
        {
            DEBUG(@"could not create folder!");
            return NO;
        }
        
        if (![[NSFileManager defaultManager] copyItemAtPath:oldbinaryPath toPath:finalPath error:NULL])
        {
            DEBUG(@"could not copy item!");
            return NO;
        }
	}


	DEBUG(@"basedir ok");
    
	MSG(CRACKING_PERFORMING_ANALYSIS);
    
	// open streams from both files
	oldbinary = fopen([oldbinaryPath UTF8String], "r+");
	newbinary = fopen([finalPath UTF8String], "r+");

	DEBUG(@"open ok");
	
	if (oldbinary==NULL)
	{
        
		if (newbinary!=NULL)
		{
			fclose(newbinary);
		}
        
		*error = [NSError errorWithDomain:@"BinaryDumpError" code:-1 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Error opening file: %s.\n", strerror(errno)]}];
        
		return NO;
	}
    
	fread(&buffer, sizeof(buffer), 1, oldbinary);
    
	DEBUG(@"local arch - %@",[self readable_cpusubtype:local_arch]);
    
	struct fat_header* fh  = (struct fat_header*) (buffer);
    
	switch (fh->magic)
	{
		MSG(CRACKING_PERFORMING_PREFLIGHT);

		//64-bit thin
		case MH_MAGIC_64:
		{
			struct mach_header_64 *mh64 = (struct mach_header_64 *)fh;
            
			DEBUG(@"64-bit Thin %@ binary detected",[self readable_cpusubtype:mh64->cpusubtype]);
            
			DEBUG(@"mach_header_64 %x %u %u",mh64->magic,mh64->cputype,mh64->cpusubtype);
            
			if (local_cputype == CPU_TYPE_ARM)
			{
				DEBUG(@"Can't crack 64bit on 32bit device");
				*error = [NSError errorWithDomain:@"BinaryDumpError" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Can't crack 64bit on 32bit device"}];
				return NO;
			}
            
			if (mh64->cpusubtype != local_arch)
			{
				DEBUG(@"Can't crack %u on %u device",mh64->cpusubtype,local_arch);
				*error = [NSError errorWithDomain:@"BinaryDumpError" code:-1 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Can't crack %u on %u device",mh64->cpusubtype,local_arch]}];
				return NO;
			}
            
			if (![self dump64bitOrigFile:oldbinary withLocation:oldbinaryPath toFile:newbinary withTop:0])
			{
				// Dumping failed
				DEBUG(@"Failed to dump %@",[self readable_cpusubtype:mh64->cpusubtype]);
				*error = [NSError errorWithDomain:@"BinaryDumpError" code:-1 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to dump %@",[self readable_cpusubtype:mh64->cpusubtype]]}];
				return NO;
			}
            
			*error = nil;
			return YES;
            
			break;
		}
            
		//32-bit thin
		case MH_MAGIC:
		{
			struct mach_header *mh32 = (struct mach_header *)fh;
            
			DEBUG(@"32bit Thin %@ binary detected",[self readable_cpusubtype:mh32->cpusubtype]);
            
			DEBUG(@"mach_header %x %u %u",mh32->magic,mh32->cputype,mh32->cpusubtype);
            
			BOOL godMode32 = NO;
            
			BOOL godMode64 = NO;
            
			if (local_cputype == CPU_TYPE_ARM64)
			{
				DEBUG(@"local_arch = God64");
				DEBUG(@"[TRU GOD MODE ENABLED]");
				godMode64 = YES;
				godMode32 = YES;
			}
            
			if ((!godMode64)&&(local_arch == CPU_SUBTYPE_ARM_V7S))
			{
				DEBUG(@"local_arch = God32");
				DEBUG(@"[32bit GOD MODE ENABLED]");
				godMode32 = YES;
			}
            
			if ((!godMode32)&&(mh32->cpusubtype>local_arch))
			{
				DEBUG(@"Can't crack 32bit(%u) on 32bit(%u) device",mh32->cpusubtype,local_arch);
				*error = [NSError errorWithDomain:@"BinaryDumpError" code:-1 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Can't crack 32bit(%@) on 32bit(%@) device",[self readable_cpusubtype:mh32->cpusubtype],[self readable_cpusubtype:local_arch]]}];
				return NO;
			}
            
			if (![self dump32bitOrigFile:oldbinary withLocation:oldbinaryPath toFile:newbinary withTop:0])
			{
				// Dumping failed
				DEBUG(@"Failed to dump %@",[self readable_cpusubtype:mh32->cpusubtype]);
				*error = [NSError errorWithDomain:@"BinaryDumpError" code:-1 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Failed to dump %@",[self readable_cpusubtype:mh32->cpusubtype]]}];
				return NO;
			}
			DEBUG(@"crack ok!");
        
			return YES;
            
			break;
		}
		//FAT
		case FAT_CIGAM:
		{
			BOOL has64 = FALSE;
			NSMutableArray *stripHeaders = [[NSMutableArray alloc] init];
            
			NSUInteger archCount = CFSwapInt32(fh->nfat_arch);
            
			struct fat_arch *arch = (struct fat_arch *) &fh[1]; //(struct fat_arch *) (fh + sizeof(struct fat_header));
            
			DEBUG(@"FAT binary detected");
            
			DEBUG(@"nfat_arch %lu",(unsigned long)archCount);
            
			for (int i = 0; i < CFSwapInt32(fh->nfat_arch); i++)
			{
				if (CFSwapInt32(arch->cputype) == CPU_TYPE_ARM64)
				{
					DEBUG(@"64bit arch detected!");
					has64 = TRUE;
					break;
				}
                
				DEBUG(@"arch arch subtype %u", arch->cputype);
				arch++;
			}
            
			arch = (struct fat_arch *) &fh[1];
            
			struct fat_arch* compatibleArch = 0;
			//loop + crack
			for (int i = 0; i < CFSwapInt32(fh->nfat_arch); i++)
			{
				DEBUG(@"currently cracking arch %u", CFSwapInt32(arch->cpusubtype));
                
				if ((arch->cputype == CPU_TYPE_ARM64) && (skip_64)) {
					DEBUG(@"Skipping arm64!");
					NSValue* archValue = [NSValue value:&arch withObjCType:@encode(struct fat_arch)];
					[stripHeaders addObject:archValue];
					break;
				}
                
				switch ([Device compatibleWith:arch])
				{
					case COMPATIBLE:
					{
						DEBUG(@"arch compatible with device!");
                        
						//go ahead and crack
						if (![self dumpOrigFile:oldbinary withLocation:oldbinaryPath toFile:newbinary withArch:*arch])
						{
							// Dumping failed
                            
							DEBUG(@"Cannot crack unswapped %@ portion of binary.", [self readable_cpusubtype:CFSwapInt32(arch->cpusubtype)]);
                            
							//*error = @"Cannot crack unswapped portion of binary.";
							fclose(newbinary); // close the new binary stream
							fclose(oldbinary); // close the old binary stream
                           
							[[NSFileManager defaultManager] removeItemAtPath:finalPath error:NULL]; // delete the new binary
                            
							if (error != NULL) *error = [NSError errorWithDomain:@"BinaryDumpError" code:-1 userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Cannot crack unswapped %@ portion of binary.",[self readable_cpusubtype:CFSwapInt32(arch->cpusubtype))}];
                            
							[stripHeaders release];
                            
							return NO;
						}
                        
						compatibleArch = arch;
						break;
                        
					}
					case NOT_COMPATIBLE:
					{
						DEBUG(@"arch not compatible with device!");
						NSValue* archValue = [NSValue value:&arch withObjCType:@encode(struct fat_arch)];
						[stripHeaders addObject:archValue];
						break;
					}
					case COMPATIBLE_SWAP:
					{
						DEBUG(@"arch compatible with device, but swap");
						NSString* stripPath;
                        
						if (has64)
						{
							stripPath = [self stripArch:arch->cpusubtype];
						}
						else
						{
							stripPath = [self swapArch:arch->cpusubtype];
						}
                        
						if (stripPath == NULL)
						{
							ERROR(@"error stripping/swapping binary!");
							if (error != NULL) *error = [NSError errorWithDomain:@"BinaryDumpError" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Error stripping/swapping binary!"}];
                            
							[stripHeaders release];
							return NO;
						}
#warning something isn't right here.
                        FILE* stripBinary = fopen([stripPath UTF8String], "r+");

                        //at this point newbinary is not fopen()'d  - should it be?
                        
						if (![self dumpOrigFile:stripBinary withLocation:stripPath toFile:newbinary withArch:*arch])
						{
							// Dumping failed
                            
							DEBUG(@"Cannot crack stripped %@ portion of binary.", [self readable_cpusubtype:CFSwapInt32(arch->cpusubtype)]);
                            
							//*error = @"Cannot crack unswapped portion of binary.";
							fclose(newbinary); // close the new binary stream
							fclose(oldbinary); // close the old binary stream
                        
							[[NSFileManager defaultManager] removeItemAtPath:finalPath error:NULL]; // delete the new binary
                            
							if (error != NULL) *error = [NSError errorWithDomain:@"BinaryDumpError" code:-1 userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Cannot crack stripped %@ portion of binary.",[self readable_cpusubtype:CFSwapInt32(arch->cpusubtype)]]}];

							[stripHeaders release];
							return NO;
						}
                        
						[self swapBack:stripPath];
						compatibleArch = arch;
                        
						break;
					}
				}
                
				if ((archCount - [stripHeaders count]) == 1)
				{
					DEBUG(@"only one architecture left!? strip");
					if (compatibleArch != NULL)
					{
						BOOL lipoSuccess = [self lipoBinary:compatibleArch];
                        
						if (!lipoSuccess)
						{
							ERROR(@"Could not lipo binary");
							if (error != NULL) *error = [NSError errorWithDomain:@"BinaryDumpError" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Could not lipo binary"}];
                            
							[stripHeaders release];
                            
							return NO;
						}
					}
                    
					if (error != NULL) *error = nil;
                    
					[stripHeaders release];
                    
					return YES;
				}
                
				arch++;
			}
            
			//strip headers
			if ([stripHeaders count] > 0)
			{
				for (NSValue* obj in stripHeaders)
				{
					struct fat_arch* stripArch;
					[obj getValue:&stripArch];
					[self removeArchitecture:stripArch];
				}
			}
            
			[stripHeaders release];
            
			break;
		}
	}
    
	if (error != NULL) *error = nil;
    
	return YES;
}
                                                                                                                                                                   

- (BOOL)dumpOrigFile:(FILE *) origin withLocation:(NSString*)originPath toFile:(FILE *) target withArch:(struct fat_arch)arch
{
	if (CFSwapInt32(arch.cputype) == CPU_TYPE_ARM64)
	{
		DEBUG(@"currently cracking 64bit portion");
		return [self dump64bitOrigFile:origin withLocation:originPath toFile:target withTop:CFSwapInt32(arch.offset)];
	}
	else
	{
		DEBUG(@"currently cracking 32bit portion");
		return [self dump32bitOrigFile:origin withLocation:originPath toFile:target withTop:CFSwapInt32(arch.offset)];
	}
	return true;
}
                                                                                                                                          
                                                                                                                                        
- (BOOL)dump64bitOrigFile:(FILE *) origin withLocation:(NSString*)originPath toFile:(FILE *) target withTop:(uint32_t) top
{
	fseek(target, top, SEEK_SET); // go the top of the target
    
	// we're going to be going to this position a lot so let's save it
	fpos_t topPosition;
	fgetpos(target, &topPosition);

	struct linkedit_data_command ldid; // LC_CODE_SIGNATURE load header (for resign)
	struct encryption_info_command_64 crypt; // LC_ENCRYPTION_INFO load header (for crypt*)
	struct mach_header_64 mach; // generic mach header
	struct load_command l_cmd; // generic load command
	struct segment_command_64 __text; // __TEXT segment
	
	struct SuperBlob *codesignblob; // codesign blob pointer
	struct CodeDirectory directory; // codesign directory index
	
	BOOL foundCrypt = FALSE;
	BOOL foundSignature = FALSE;
	BOOL foundStartText = FALSE;
	uint64_t __text_start = 0;
	//uint64_t __text_size = 0;
	MSG(DUMPING_ANALYZE_LOAD_COMMAND);
    
	fread(&mach, sizeof(struct mach_header_64), 1, target); // read mach header to get number of load commands
	for (int lc_index = 0; lc_index < mach.ncmds; lc_index++) { // iterate over each load command
		fread(&l_cmd, sizeof(struct load_command), 1, target); // read load command from binary
		//DEBUG(@"command: %u", CFSwapInt32(l_cmd.cmd));
		if (l_cmd.cmd == LC_ENCRYPTION_INFO_64) { // encryption info?
			fseek(target, -1 * sizeof(struct load_command), SEEK_CUR);
			fread(&crypt, sizeof(struct encryption_info_command_64), 1, target);
			DEBUG(@"found cryptid");
			foundCrypt = TRUE; // remember that it was found
		} else if (l_cmd.cmd == LC_CODE_SIGNATURE) { // code signature?
			fseek(target, -1 * sizeof(struct load_command), SEEK_CUR);
			fread(&ldid, sizeof(struct linkedit_data_command), 1, target);
			DEBUG(@"found code signature");
			foundSignature = TRUE; // remember that it was found
		} else if (l_cmd.cmd == LC_SEGMENT_64) {
			// some applications, like Skype, have decided to start offsetting the executable image's
			// vm regions by substantial amounts for no apparant reason. this will find the vmaddr of
			// that segment (referenced later during dumping)
			fseek(target, -1 * sizeof(struct load_command), SEEK_CUR);
			fread(&__text, sizeof(struct segment_command_64), 1, target);
			if (strncmp(__text.segname, "__TEXT", 6) == 0) {
				foundStartText = TRUE;
				DEBUG(@"found start text");
				__text_start = __text.vmaddr;
				//__text_size = __text.vmsize; // This has been a dead store since Clutch 1.0 I think
                
			}
			fseek(target, l_cmd.cmdsize - sizeof(struct segment_command_64), SEEK_CUR);
		} else {
			fseek(target, l_cmd.cmdsize - sizeof(struct load_command), SEEK_CUR); // seek over the load command
		}
		if (foundCrypt && foundSignature && foundStartText)
			break;
	}
    
	// we need to have found both of these
	if (!foundCrypt || !foundSignature || !foundStartText) {
		VERBOSE("dumping binary: some load commands were not found");
		return FALSE;
	}
    
	if (patchPIE) {
		printf("patching pie\n");
		MSG(DUMPING_ASLR_ENABLED);
		mach.flags &= ~MH_PIE;
		fseek(origin, top, SEEK_SET);
		fwrite(&mach, sizeof(struct mach_header_64), 1, origin);
	}
	
	pid_t pid; // store the process ID of the fork
	mach_port_t port; // mach port used for moving virtual memory
	kern_return_t err; // any kernel return codes
	int status; // status of the wait
	mach_vm_size_t local_size = 0; // amount of data moved into the buffer
	uint64_t begin;
	
	//VERBOSE("dumping binary: obtaining ptrace handle");
	MSG(DUMPING_OBTAIN_PTRACE);
    
	// open handle to dylib loader
	void *handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
	// load ptrace library into handle
	ptrace_ptr_t ptrace = dlsym(handle, "ptrace");
	// begin the forking process
	MSG(DUMPING_FORKING);
    
	if ((pid = fork()) == 0) {
		// it worked! the magic is in allowing the process to trace before execl.
		// the process will be incapable of preventing itself from tracing
		// execl stops the process before this is capable
		// PT_DENY_ATTACH was never meant to be good security, only a minor roadblock
		
		ptrace(PT_TRACE_ME, 0, 0, 0); // trace
		execl([originPath UTF8String], "", (char *) 0); // import binary memory into executable space
        
		exit(2); // exit with err code 2 in case we could not import (this should not happen)
	} else if (pid < 0) {
		printf("error: Couldn't fork, did you compile with proper entitlements?");
		return FALSE; // couldn't fork
	} else {
		// wait until the binary stops
		do {
			wait(&status);
			if (WIFEXITED( status ))
				return FALSE;
		} while (!WIFSTOPPED( status ));
		
		//VERBOSE("dumping binary: obtaining mach port");
		MSG(DUMPING_OBTAIN_MACH_PORT);
        
		// open mach port to the other process
        
#warning CRASH HERE - no ptrace, in dyld cache we need to fix thiiiiiis
    
		if ((err = task_for_pid(mach_task_self(), pid, &port) != KERN_SUCCESS)) {
			VERBOSE("ERROR: Could not obtain mach port, did you sign with proper entitlements?");
			kill(pid, SIGKILL); // kill the fork
			return FALSE;
		}
		
		//VERBOSE("dumping binary: preparing code resign");
		MSG(DUMPING_CODE_RESIGN);
        
#warning Does this need to be updated for 64-bit as well?
        
		DEBUG(@"64-bit code resign");

		codesignblob = malloc(ldid.datasize);
        
		fseek(target, top + ldid.dataoff, SEEK_SET); // seek to the codesign blob
		fread(codesignblob, ldid.datasize, 1, target); // read the whole codesign blob
		uint64_t countBlobs = CFSwapInt32(codesignblob->count); // how many indexes?
		
		// iterate through each index
		for (uint64_t index = 0; index < countBlobs; index++) {
			if (CFSwapInt32(codesignblob->index[index].type) == CSSLOT_CODEDIRECTORY) { // is this the code directory?
				// we'll find the hash metadata in here
				begin = top + ldid.dataoff + CFSwapInt32(codesignblob->index[index].offset); // store the top of the codesign directory blob
				fseek(target, begin, SEEK_SET); // seek to the beginning of the blob
				fread(&directory, sizeof(struct CodeDirectory), 1, target); // read the blob
				break; // break (we don't need anything from this the superblob anymore)
			}
		}
		
		free(codesignblob); // free the codesign blob
        
		uint32_t pages = CFSwapInt32(directory.nCodeSlots); // get the amount of codeslots
        
		if (pages == 0) {
			kill(pid, SIGKILL); // kill the fork
			DEBUG(@"pages == 0");
			return FALSE;
		}
		
		void *checksum = malloc(pages * 20); // 160 bits for each hash (SHA1)
		uint8_t buf_d[0x1000]; // create a single page buffer
		uint8_t *buf = &buf_d[0]; // store the location of the buffer
		
		//VERBOSE("dumping binary: preparing to dump");
		MSG(DUMPING_PREPARE_DUMP);
        
		// we should only have to write and perform checksums on data that changes
		uint32_t togo = crypt.cryptsize + crypt.cryptoff;
		uint32_t total = togo;
		uint32_t pages_d = 0;
		BOOL header = TRUE;
		
		// write the header
		fsetpos(target, &topPosition);
		
		// in iOS 4.3+, ASLR can be enabled by developers by setting the MH_PIE flag in
		// the mach header flags. this will randomly offset the location of the __TEXT
		// segment, making it slightly difficult to identify the location of the
		// decrypted pages. instead of disabling this flag in the original binary
		// (which is slow, requires resigning, and requires reverting to the original
		// binary after cracking) we instead manually identify the vm regions which
		// contain the header and subsequent decrypted executable code.
		if ((mach.flags & MH_PIE) && (!patchPIE)) {
			//VERBOSE("dumping binary: ASLR enabled, identifying dump location dynamically");
			MSG(DUMPING_ASLR_ENABLED);
            
			// perform checks on vm regions
			memory_object_name_t object;
			vm_region_basic_info_data_t info;
			//mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT;
			mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_UNIV;
			mach_vm_address_t region_start = 0;
			mach_vm_size_t region_size = 0;
			vm_region_flavor_t flavor = VM_REGION_BASIC_INFO;
			err = 0;
			
			while (err == KERN_SUCCESS)
			{
				err = mach_vm_region(port, &region_start, &region_size, flavor, (vm_region_info_t) &info, &info_count, &object);
				DEBUG(@"64-bit Region Size: %llu %u", region_size, crypt.cryptsize);
                
				if (region_size == crypt.cryptsize)
				{
					DEBUG(@"region_size == cryptsize");
					break;
				}
                
				__text_start = region_start;
				region_start += region_size;
				region_size	= 0;
                
			}
            
			if (err != KERN_SUCCESS)
			{
				DEBUG(@"mach_vm_error: %u", err);
				free(checksum);
				kill(pid, SIGKILL);
				printf("ASLR is enabled and we could not identify the decrypted memory region.\n");
				return FALSE;
				
			}
		}
		
		uint32_t headerProgress = sizeof(struct mach_header_64);
		uint32_t i_lcmd = 0;
        
		// overdrive dylib load command size
		uint32_t overdrive_size = sizeof(OVERDRIVE_DYLIB_PATH) + sizeof(struct dylib_command);
		overdrive_size += sizeof(long) - (overdrive_size % sizeof(long)); // load commands like to be aligned by long
        
		//VERBOSE("dumping binary: performing dump");
		MSG(DUMPING_PERFORM_DUMP);
        
		while (togo > 0) {
			// get a percentage for the progress bar
			PERCENT((int)ceil((((double)total - togo) / (double)total) * 100));
			// move an entire page into memory (we have to move an entire page regardless of whether it's a resultant or not)
			if((err = mach_vm_read_overwrite(port, (mach_vm_address_t) __text_start + (pages_d * 0x1000), (vm_size_t) 0x1000, (pointer_t) buf, &local_size)) != KERN_SUCCESS)	{
				DEBUG(@"dum_error: %u", err);
				VERBOSE("dumping binary: failed to dump a page (64)");
                
				if (__text_start == 0x4000) {
					printf("\n=================\n");
					printf("0x4000 binary detected, attempting to remove MH_PIE flag");
					printf("\n=================\n\n");
					free(checksum); // free checksum table
					kill(pid, SIGKILL); // kill fork
                    [self patchPIE:TRUE];
					return [self dump64bitOrigFile:origin withLocation:originPath toFile:target withTop:top];
				}
                
				free(checksum); // free checksum table
				kill(pid, SIGKILL); // kill fork
                
				return FALSE;
			}
			
			if (header) {
				// is this the first header page?
				if (i_lcmd == 0) {
					// is overdrive enabled?
					if (overdriveEnabled) {
						// prepare the mach header for the new load command (overdrive dylib)
						((struct mach_header *)buf)->ncmds += 1;
						((struct mach_header *)buf)->sizeofcmds += overdrive_size;
						//VERBOSE("dumping binary: patched mach header (overdrive)");
						MSG(DUMPING_OVERDRIVE_PATCH_HEADER);
					}
				}
				// iterate over the header (or resume iteration)
				void *curloc = buf + headerProgress;
				for (;i_lcmd<mach.ncmds;i_lcmd++) {
					struct load_command *l_cmd = (struct load_command *) curloc;
					// is the load command size in a different page?
					uint32_t lcmd_size;
					if ((int)(((void*)curloc - (void*)buf) + 4) == 0x1000) {
						// load command size is at the start of the next page
						// we need to get it
						mach_vm_read_overwrite(port, (mach_vm_address_t) __text_start + ((pages_d+1) * 0x1000), (vm_size_t) 0x1, (pointer_t) &lcmd_size, &local_size);
						//vm_read_overwrite(port, (mach_vm_address_t) __text_start + ((pages_d+1) * 0x1000), (vm_size_t) 0x1, (pointer_t) &lcmd_size, &local_size);
					} else {
						lcmd_size = l_cmd->cmdsize;
					}
                    
					if (l_cmd->cmd == LC_ENCRYPTION_INFO_64) {
						struct encryption_info_command_64 *newcrypt = (struct encryption_info_command_64 *) curloc;
						newcrypt->cryptid = 0; // change the cryptid to 0
						MSG(DUMPING_PATCH_CRYPTID);

					} else if (l_cmd->cmd == LC_SEGMENT) {
						struct segment_command *newseg = (struct segment_command *) curloc;
						if (newseg->fileoff == 0 && newseg->filesize > 0) {
							// is overdrive enabled? this is __TEXT
							if (overdriveEnabled) {
								// maxprot so that overdrive can change the __TEXT protection &
								// cryptid in realtime
								newseg->maxprot |= VM_PROT_ALL;
								MSG(DUMPING_OVERDRIVE_PATCH_MAXPROT);
								//VERBOSE("dumping binary: patched maxprot (overdrive)");
							}
						}
					}
					curloc += lcmd_size;
					if ((void *)curloc >= (void *)buf + 0x1000) {
						//printf("skipped pass the haeder yo\n");
						// we are currently extended past the header page
						// offset for the next round:
						headerProgress = (((void *)curloc - (void *)buf) % 0x1000);
						// prevent attaching overdrive dylib by skipping
						goto skipoverdrive;
					}
				}
				// is overdrive enabled?
				if (overdriveEnabled) {
					// add the overdrive dylib as long as we have room
					if ((int8_t*)(curloc + overdrive_size) < (int8_t*)(buf + 0x1000)) {
						MSG(DUMPING_OVERDRIVE_ATTACH_DYLIB);
						//VERBOSE("dumping binary: attaching overdrive DYLIB (overdrive)");
						struct dylib_command *overdrive_dyld = (struct dylib_command *) curloc;
						overdrive_dyld->cmd = LC_LOAD_DYLIB;
						overdrive_dyld->cmdsize = overdrive_size;
						overdrive_dyld->dylib.compatibility_version = OVERDRIVE_DYLIB_COMPATIBILITY_VERSION;
						overdrive_dyld->dylib.current_version = OVERDRIVE_DYLIB_CURRENT_VER;
						overdrive_dyld->dylib.timestamp = 2;
						overdrive_dyld->dylib.name.offset = sizeof(struct dylib_command);

						char *p = (char *) overdrive_dyld + overdrive_dyld->dylib.name.offset;
						strncpy(p, OVERDRIVE_DYLIB_PATH.UTF8String, sizeof(OVERDRIVE_DYLIB_PATH));
					}
				}
				header = FALSE;
			}
			skipoverdrive:
			//printf("attemtping to write to binary\n");
			fwrite(buf, 0x1000, 1, target); // write the new data to the target
			sha1(checksum + (20 * pages_d), buf, 0x1000); // perform checksum on the page
			//printf("doing checksum yo\n");
			togo -= 0x1000; // remove a page from the togo
			//printf("togo yo %u\n", togo);
			pages_d += 1; // increase the amount of completed pages
		}
        
		//VERBOSE("dumping binary: writing new checksum");
		printf("\n");
		MSG(DUMPING_NEW_CHECKSUM);
        
		// nice! now let's write the new checksum data
		fseek(target, begin + CFSwapInt64(directory.hashOffset), SEEK_SET); // go to the hash offset
		fwrite(checksum, 20*pages_d, 1, target); // write the hashes (ONLY for the amount of pages modified)
		
		free(checksum); // free checksum table from memory
		kill(pid, SIGKILL); // kill the fork
	}
	stop_bar();
	return TRUE;

}
                                                                                                                                                
- (BOOL)dump32bitOrigFile:(FILE *) origin withLocation:(NSString*)originPath toFile:(FILE *) target withTop:(uint32_t) top
{
	DEBUG(@"Dumping 32bit segment..");
    if (target == NULL)
    {
        printf("Target is null, wtf? - %s\n", strerror(errno));
        
        target = fopen(newbinaryPath.UTF8String, "r+");
        
        
    }
	fseek(target, top, SEEK_SET); // go the top of the target
	// we're going to be going to this position a lot so let's save it
	fpos_t topPosition;
	fgetpos(target, &topPosition);
	
	struct linkedit_data_command ldid; // LC_CODE_SIGNATURE load header (for resign)
	struct encryption_info_command crypt; // LC_ENCRYPTION_INFO load header (for crypt*)
	struct mach_header mach; // generic mach header
	struct load_command l_cmd; // generic load command
	struct segment_command __text; // __TEXT segment
	
	struct SuperBlob *codesignblob; // codesign blob pointer
	struct CodeDirectory directory; // codesign directory index
	
	BOOL foundCrypt = FALSE;
	BOOL foundSignature = FALSE;
	BOOL foundStartText = FALSE;
    // HMM
	uint64_t __text_start = 0;
	//uint64_t __text_size = 0;
	DEBUG(@"32bit dumping: offset %u", top);
	//VERBOSE("dumping binary: analyzing load commands");
	MSG(DUMPING_ANALYZE_LOAD_COMMAND);
	fread(&mach, sizeof(struct mach_header), 1, target); // read mach header to get number of load commands
    
	for (int lc_index = 0; lc_index < mach.ncmds; lc_index++) { // iterate over each load command
		fread(&l_cmd, sizeof(struct load_command), 1, target); // read load command from binary
		if (l_cmd.cmd == LC_ENCRYPTION_INFO) { // encryption info?
			fseek(target, -1 * sizeof(struct load_command), SEEK_CUR);
			fread(&crypt, sizeof(struct encryption_info_command), 1, target);
			foundCrypt = TRUE; // remember that it was found
			DEBUG(@"found encryption info");
		} else if (l_cmd.cmd == LC_CODE_SIGNATURE) { // code signature?
			fseek(target, -1 * sizeof(struct load_command), SEEK_CUR);
			fread(&ldid, sizeof(struct linkedit_data_command), 1, target);
			foundSignature = TRUE; // remember that it was found
			DEBUG(@"found code signature");
		} else if (l_cmd.cmd == LC_SEGMENT) {
			// some applications, like Skype, have decided to start offsetting the executable image's
			// vm regions by substantial amounts for no apparant reason. this will find the vmaddr of
			// that segment (referenced later during dumping)
			fseek(target, -1 * sizeof(struct load_command), SEEK_CUR);
			fread(&__text, sizeof(struct segment_command), 1, target);
            
			if (strncmp(__text.segname, "__TEXT", 6) == 0) {
				foundStartText = TRUE;
				__text_start = __text.vmaddr;
				//__text_size = __text.vmsize; This has been a dead store since Clutch 1.0 I think
			}
			fseek(target, l_cmd.cmdsize - sizeof(struct segment_command), SEEK_CUR);
			DEBUG(@"found segment");
		} else {
			fseek(target, l_cmd.cmdsize - sizeof(struct load_command), SEEK_CUR); // seek over the load command
		}
        
		if (foundCrypt && foundSignature && foundStartText)
			break;
	}
	
	// we need to have found both of these
	if (!foundCrypt || !foundSignature || !foundStartText) {
		VERBOSE("dumping binary: some load commands were not found");
		return FALSE;
	}
    
	if (patchPIE) {
		printf("patching pie\n");
		MSG(DUMPING_ASLR_ENABLED);
		mach.flags &= ~MH_PIE;
		fseek(origin, top, SEEK_SET);
		fwrite(&mach, sizeof(struct mach_header), 1, origin);
	}
	
	pid_t pid; // store the process ID of the fork
	mach_port_t port; // mach port used for moving virtual memory
	kern_return_t err; // any kernel return codes
	int status; // status of the wait
	//vm_size_t local_size = 0; // amount of data moved into the buffer
	mach_vm_size_t local_size = 0; // amount of data moved into the buffer
	uint32_t begin;
	
	//VERBOSE("dumping binary: obtaining ptrace handle");
	MSG(DUMPING_OBTAIN_PTRACE);
    
	// open handle to dylib loader
	void *handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
	// load ptrace library into handle
	ptrace_ptr_t ptrace = dlsym(handle, "ptrace");
	// begin the forking process
	//VERBOSE("dumping binary: forking to begin tracing");
	MSG(DUMPING_FORKING);
    
	if ((pid = fork()) == 0) {
		// it worked! the magic is in allowing the process to trace before execl.
		// the process will be incapable of preventing itself from tracing
		// execl stops the process before this is capable
		// PT_DENY_ATTACH was never meant to be good security, only a minor roadblock
        
		MSG(DUMPING_FORK_SUCCESS);
		
		ptrace(PT_TRACE_ME, 0, 0, 0); // trace
		execl([originPath UTF8String], "", (char *) 0); // import binary memory into executable space
        
		exit(2); // exit with err code 2 in case we could not import (this should not happen)
	} else if (pid < 0) {
		printf("error: Couldn't fork, did you compile with proper entitlements?");
		return FALSE; // couldn't fork
	} else {
		// wait until the binary stops
		do {
			wait(&status);
			if (WIFEXITED( status ))
				return FALSE;
		} while (!WIFSTOPPED( status ));
		
		//VERBOSE("dumping binary: obtaining mach port");
		MSG(DUMPING_OBTAIN_MACH_PORT);
        
		// open mach port to the other process
		if ((err = task_for_pid(mach_task_self(), pid, &port) != KERN_SUCCESS)) {
			VERBOSE("ERROR: Could not obtain mach port, did you sign with proper entitlements?");
			kill(pid, SIGKILL); // kill the fork
			return FALSE;
		}
		
		//VERBOSE("dumping binary: preparing code resign");
		MSG(DUMPING_CODE_RESIGN);
        
		codesignblob = malloc(ldid.datasize);
		fseek(target, top + ldid.dataoff, SEEK_SET); // seek to the codesign blob
		fread(codesignblob, ldid.datasize, 1, target); // read the whole codesign blob
		uint32_t countBlobs = CFSwapInt32(codesignblob->count); // how many indexes?
		
		// iterate through each index
		for (uint32_t index = 0; index < countBlobs; index++) {
			if (CFSwapInt32(codesignblob->index[index].type) == CSSLOT_CODEDIRECTORY) { // is this the code directory?
				// we'll find the hash metadata in here
				begin = top + ldid.dataoff + CFSwapInt32(codesignblob->index[index].offset); // store the top of the codesign directory blob
				fseek(target, begin, SEEK_SET); // seek to the beginning of the blob
				fread(&directory, sizeof(struct CodeDirectory), 1, target); // read the blob
				break; // break (we don't need anything from this the superblob anymore)
			}
		}
		
		free(codesignblob); // free the codesign blob
		
		uint32_t pages = CFSwapInt32(directory.nCodeSlots); // get the amount of codeslots
        
		if (pages == 0) {
			kill(pid, SIGKILL); // kill the fork
			return FALSE;
		}
		
		void *checksum = malloc(pages * 20); // 160 bits for each hash (SHA1)
		uint8_t buf_d[0x1000]; // create a single page buffer
		uint8_t *buf = &buf_d[0]; // store the location of the buffer
		
		//VERBOSE("dumping binary: preparing to dump");
		MSG(DUMPING_PREPARE_DUMP);
        
		// we should only have to write and perform checksums on data that changes
		uint32_t togo = crypt.cryptsize + crypt.cryptoff;
		uint32_t total = togo;
		uint32_t pages_d = 0;
		BOOL header = TRUE;
		
		// write the header
		fsetpos(target, &topPosition);
		
		// in iOS 4.3+, ASLR can be enabled by developers by setting the MH_PIE flag in
		// the mach header flags. this will randomly offset the location of the __TEXT
		// segment, making it slightly difficult to identify the location of the
		// decrypted pages. instead of disabling this flag in the original binary
		// (which is slow, requires resigning, and requires reverting to the original
		// binary after cracking) we instead manually identify the vm regions which
		// contain the header and subsequent decrypted executable code.
        
		if ((mach.flags & MH_PIE) && (!patchPIE)) {
			//VERBOSE("dumping binary: ASLR enabled, identifying dump location dynamically");
			MSG(DUMPING_ASLR_ENABLED);
			// perform checks on vm regions
			memory_object_name_t object;
			vm_region_basic_info_data_t info;
			mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT_UNIV; // 32/64bit :P
			mach_vm_address_t region_start = 0;
			mach_vm_size_t region_size = 0;
			vm_region_flavor_t flavor = VM_REGION_BASIC_INFO;
			err = 0;
            
			while (err == KERN_SUCCESS) {
				err = mach_vm_region(port, &region_start, &region_size, flavor, (vm_region_info_t) &info, &info_count, &object);
                
				DEBUG(@"32-bit Region Size: %llu %u", region_size, crypt.cryptsize);
                
				if ((uint32_t)region_size == crypt.cryptsize) {
					break;
				}
				__text_start = region_start;
				region_start += region_size;
				region_size        = 0;
			}
			if (err != KERN_SUCCESS) {
				free(checksum);
				DEBUG(@"32-bit mach_vm_error: %u", err);
				printf("ASLR is enabled and we could not identify the decrypted memory region.\n");
				kill(pid, SIGKILL);
				return FALSE;
                
			}
		}
        
        
		uint32_t headerProgress = sizeof(struct mach_header);
		uint32_t i_lcmd = 0;
        
		// overdrive dylib load command size
		uint32_t overdrive_size = sizeof(OVERDRIVE_DYLIB_PATH) + sizeof(struct dylib_command);
		overdrive_size += sizeof(long) - (overdrive_size % sizeof(long)); // load commands like to be aligned by long
        
		MSG(DUMPING_PERFORM_DUMP);
        
		while (togo > 0) {
			// get a percentage for the progress bar
			PERCENT((int)ceil((((double)total - togo) / (double)total) * 100));
            
            
			if ((err = mach_vm_read_overwrite(port, (mach_vm_address_t) __text_start + (pages_d * 0x1000), (vm_size_t) 0x1000, (pointer_t) buf, &local_size)) != KERN_SUCCESS)	{
                
				printf("dumping binary: failed to dump a page (32)\n");
				if (__text_start == 0x4000) {
					printf("\n=================\n");
					printf("0x4000 binary detected, attempting to remove MH_PIE flag");
					printf("\n=================\n\n");
					free(checksum); // free checksum table
					kill(pid, SIGKILL); // kill the fork
                    [self patchPIE:TRUE];
					return [self dump32bitOrigFile:origin withLocation:originPath toFile:target withTop:top];
				}
				free(checksum); // free checksum table
				kill(pid, SIGKILL); // kill the fork
                
				return FALSE;
			}
            
            
			if (header) {
				// is this the first header page?
				if (i_lcmd == 0) {
					// is overdrive enabled?
					if (overdriveEnabled) {
						// prepare the mach header for the new load command (overdrive dylib)
						((struct mach_header *)buf)->ncmds += 1;
						((struct mach_header *)buf)->sizeofcmds += overdrive_size;
						//VERBOSE("dumping binary: patched mach header (overdrive)");
						MSG(DUMPING_OVERDRIVE_PATCH_HEADER);
					}
				}
				// iterate over the header (or resume iteration)
				void *curloc = buf + headerProgress;
				for (;i_lcmd<mach.ncmds;i_lcmd++) {
					struct load_command *l_cmd = (struct load_command *) curloc;
					// is the load command size in a different page?
					uint32_t lcmd_size;
					if ((int)(((void*)curloc - (void*)buf) + 4) == 0x1000) {
						// load command size is at the start of the next page
						// we need to get it
						//vm_read_overwrite(port, (mach_vm_address_t) __text_start + ((pages_d+1) * 0x1000), (vm_size_t) 0x1, (pointer_t) &lcmd_size, &local_size);
						mach_vm_read_overwrite(port, (mach_vm_address_t) __text_start + ((pages_d + 1) * 0x1000), (vm_size_t) 0x1, (mach_vm_address_t) &lcmd_size, &local_size);
						//printf("ieterating through header\n");
					} else {
						lcmd_size = l_cmd->cmdsize;
					}
                    
					if (l_cmd->cmd == LC_ENCRYPTION_INFO) {
						struct encryption_info_command *newcrypt = (struct encryption_info_command *) curloc;
						newcrypt->cryptid = 0; // change the cryptid to 0
						//VERBOSE("dumping binary: patched cryptid");
						MSG(DUMPING_PATCH_CRYPTID);
					} else if (l_cmd->cmd == LC_SEGMENT) {
						//printf("lc segemn yo\n");
						struct segment_command *newseg = (struct segment_command *) curloc;
						if (newseg->fileoff == 0 && newseg->filesize > 0) {
							// is overdrive enabled? this is __TEXT
							if (overdriveEnabled) {
								// maxprot so that overdrive can change the __TEXT protection &
								// cryptid in realtime
								newseg->maxprot |= VM_PROT_ALL;
								//VERBOSE("dumping binary: patched maxprot (overdrive)");
								MSG(DUMPING_OVERDRIVE_PATCH_MAXPROT);

							}
						}
					}
					curloc += lcmd_size;
					if ((void *)curloc >= (void *)buf + 0x1000) {
						//printf("skipped pass the haeder yo\n");
						// we are currently extended past the header page
						// offset for the next round:
						headerProgress = (((void *)curloc - (void *)buf) % 0x1000);
						// prevent attaching overdrive dylib by skipping
						goto skipoverdrive;
					}
				}
				// is overdrive enabled?
				if (overdriveEnabled) {
					// add the overdrive dylib as long as we have room
					if ((int8_t*)(curloc + overdrive_size) < (int8_t*)(buf + 0x1000)) {
						//VERBOSE("dumping binary: attaching overdrive DYLIB (overdrive)");
						MSG(DUMPING_OVERDRIVE_ATTACH_DYLIB);
						struct dylib_command *overdrive_dyld = (struct dylib_command *) curloc;
						overdrive_dyld->cmd = LC_LOAD_DYLIB;
						overdrive_dyld->cmdsize = overdrive_size;
						overdrive_dyld->dylib.compatibility_version = OVERDRIVE_DYLIB_COMPATIBILITY_VERSION;
						overdrive_dyld->dylib.current_version = OVERDRIVE_DYLIB_CURRENT_VER;
						overdrive_dyld->dylib.timestamp = 2;
						overdrive_dyld->dylib.name.offset = sizeof(struct dylib_command);
#ifndef __LP64__
						overdrive_dyld->dylib.name.ptr = (char *) sizeof(struct dylib_command);
#endif
						char *p = (char *) overdrive_dyld + overdrive_dyld->dylib.name.offset;
						strncpy(p, OVERDRIVE_DYLIB_PATH.UTF8String, OVERDRIVE_DYLIB_PATH.length);
					}
				}
				header = FALSE;
			}
			skipoverdrive:
			//printf("attemtping to write to binary\n");
			fwrite(buf, 0x1000, 1, target); // write the new data to the target
			sha1(checksum + (20 * pages_d), buf, 0x1000); // perform checksum on the page
			//printf("doing checksum yo\n");
			togo -= 0x1000; // remove a page from the togo
			//printf("togo yo %u\n", togo);
			pages_d += 1; // increase the amount of completed pages
		}
        
		//VERBOSE("dumping binary: writing new checksum");
		printf("\n");
		MSG(DUMPING_NEW_CHECKSUM);
        
		// nice! now let's write the new checksum data
		fseek(target, begin + CFSwapInt32(directory.hashOffset), SEEK_SET); // go to the hash offset
		fwrite(checksum, 20*pages_d, 1, target); // write the hashes (ONLY for the amount of pages modified)
		
		free(checksum); // free checksum table from memory
		kill(pid, SIGKILL); // kill the fork
	}
	stop_bar();
	return TRUE;
}

- (NSString *)swapArch:(cpu_subtype_t) swaparch
{
	NSString *workingPath = oldbinaryPath;
    
	NSString *baseName = [workingPath lastPathComponent];
    
	NSString *baseDirectory = [NSString stringWithFormat:@"%@/", [workingPath stringByDeletingLastPathComponent]];
    
	char swapBuffer[4096];
	DEBUG(@"##### SWAPPING ARCH #####");
	DEBUG(@"local arch %@", [self readable_cpusubtype:local_arch]);
    
	if (local_arch == swaparch) {
		NSLog(@"UH HELLRO PLIS");
		return NULL;
	}
    
	NSString* suffix = [NSString stringWithFormat:@"%@_lwork", [self readable_cpusubtype:OSSwapInt32(swaparch)]];
	workingPath = [NSString stringWithFormat:@"%@_%@", workingPath, suffix]; // assign new path
    
	[[NSFileManager defaultManager] copyItemAtPath:oldbinaryPath toPath:workingPath error: NULL];
    
	FILE* swapbinary = fopen([workingPath UTF8String], "r+");
    
	fseek(swapbinary, 0, SEEK_SET);
	fread(&swapBuffer, sizeof(swapBuffer), 1, swapbinary);
	struct fat_header* swapfh = (struct fat_header*) (swapBuffer);
    
	int i;

	struct fat_arch *arch = (struct fat_arch *) &swapfh[1];
	cpu_type_t swap_cputype = 0;
	cpu_subtype_t largest_cpusubtype = 0;
	NSLog(@"arch arch arch ok ok");
    
	for (i = CFSwapInt32(swapfh->nfat_arch); i--;) {
		if (arch->cpusubtype == swaparch) {
			DEBUG(@"found arch to swap! %u", OSSwapInt32(swaparch));
			swap_cputype = arch->cputype;
		}
		if (arch->cpusubtype > largest_cpusubtype) {
			largest_cpusubtype = arch->cpusubtype;
		}
		arch++;
	}
	DEBUG(@"largest_cpusubtype: %u", CFSwapInt32(largest_cpusubtype));
    
	arch = (struct fat_arch *) &swapfh[1];
    
	for (i = CFSwapInt32(swapfh->nfat_arch); i--;) {
		if (arch->cpusubtype == largest_cpusubtype) {
			if (swap_cputype != arch->cputype) {
				DEBUG(@"ERROR: cputypes to swap are incompatible!");
				return false;
			}
			arch->cpusubtype = swaparch;
			DEBUG(@"swapp swapp: replaced %u's cpusubtype to %u", CFSwapInt32(arch->cpusubtype), CFSwapInt32(swaparch));
		}
		else if (arch->cpusubtype == swaparch) {
			arch->cpusubtype = largest_cpusubtype;
			DEBUG(@"swap swap: replaced %u's cpusubtype to %u", CFSwapInt32(arch->cpusubtype), CFSwapInt32(largest_cpusubtype));
		}
		arch++;
	}
    
	//move the SC_Info keys
    
	NSString *scinfo_prefix = [baseDirectory stringByAppendingFormat:@"SC_Info/%@", baseName];
    
	sinfPath = [NSString stringWithFormat:@"%@_%@.sinf", scinfo_prefix, suffix];
	suppPath = [NSString stringWithFormat:@"%@_%@.supp", scinfo_prefix, suffix];
	supfPath = [NSString stringWithFormat:@"%@_%@.supf", scinfo_prefix, suffix];
    
	if ([[NSFileManager defaultManager] fileExistsAtPath:[scinfo_prefix stringByAppendingString:@".supf"]]) {
		[[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".supf"] toPath:supfPath error:NULL];
	}
	[[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".sinf"] toPath:sinfPath error:NULL];
	[[NSFileManager defaultManager] copyItemAtPath:[scinfo_prefix stringByAppendingString:@".supp"] toPath:suppPath error:NULL];
    
	fseek(swapbinary, 0, SEEK_SET);
	fwrite(swapBuffer, sizeof(swapBuffer), 1, swapbinary);
    
	DEBUG(@"swap: Wrote new arch info");
    
	fclose(swapbinary);
    
	return workingPath;
}

- (void)swapBack:(NSString *)path
{
	[[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:sinfPath error:NULL];
	[[NSFileManager defaultManager] removeItemAtPath:suppPath error:NULL];
	if ([[NSFileManager defaultManager] fileExistsAtPath:supfPath]) {
		[[NSFileManager defaultManager] removeItemAtPath:supfPath error:NULL];
	}
}

@end

void sha1(uint8_t *hash, uint8_t *data, size_t size) {
	SHA1Context context;
	SHA1Reset(&context);
	SHA1Input(&context, data, (unsigned)size);
	SHA1Result(&context, hash);
}
