#import "dump.h"

BOOL dump_binary(FILE *origin, FILE *target, uint32_t top, NSString *originPath) {
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
	uint32_t __text_start = 0;
	uint32_t __text_size = 0;
    VERBOSE("dumping binary: analyzing load commands");
	fread(&mach, sizeof(struct mach_header), 1, target); // read mach header to get number of load commands
	for (int lc_index = 0; lc_index < mach.ncmds; lc_index++) { // iterate over each load command
		fread(&l_cmd, sizeof(struct load_command), 1, target); // read load command from binary
		if (l_cmd.cmd == LC_ENCRYPTION_INFO) { // encryption info?
			fseek(target, -1 * sizeof(struct load_command), SEEK_CUR);
			fread(&crypt, sizeof(struct encryption_info_command), 1, target);
			foundCrypt = TRUE; // remember that it was found
		} else if (l_cmd.cmd == LC_CODE_SIGNATURE) { // code signature?
			fseek(target, -1 * sizeof(struct load_command), SEEK_CUR);
			fread(&ldid, sizeof(struct linkedit_data_command), 1, target);
			foundSignature = TRUE; // remember that it was found
		} else if (l_cmd.cmd == LC_SEGMENT) {
			// some applications, like Skype, have decided to start offsetting the executable image's
			// vm regions by substantial amounts for no apparant reason. this will find the vmaddr of
			// that segment (referenced later during dumping)
			fseek(target, -1 * sizeof(struct load_command), SEEK_CUR);
			fread(&__text, sizeof(struct segment_command), 1, target);
			if (strncmp(__text.segname, "__TEXT", 6) == 0) {
				foundStartText = TRUE;
				__text_start = __text.vmaddr;
				__text_size = __text.vmsize;
			}
			fseek(target, l_cmd.cmdsize - sizeof(struct segment_command), SEEK_CUR);
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
	
	pid_t pid; // store the process ID of the fork
	mach_port_t port; // mach port used for moving virtual memory
	kern_return_t err; // any kernel return codes
	int status; // status of the wait
	vm_size_t local_size = 0; // amount of data moved into the buffer
	uint32_t begin;
	
    VERBOSE("dumping binary: obtaining ptrace handle");
    
	// open handle to dylib loader
	void *handle = dlopen(0, RTLD_GLOBAL | RTLD_NOW);
	// load ptrace library into handle
	ptrace_ptr_t ptrace = dlsym(handle, "ptrace");
	// begin the forking process
    VERBOSE("dumping binary: forking to begin tracing");
    
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
		
        VERBOSE("dumping binary: obtaining mach port");
        
		// open mach port to the other process
		if ((err = task_for_pid(mach_task_self(), pid, &port) != KERN_SUCCESS)) {
            VERBOSE("ERROR: Could not obtain mach port, did you sign with proper entitlements?");
			kill(pid, SIGKILL); // kill the fork
			return FALSE;
		}
		
        VERBOSE("dumping binary: preparing code resign");
        
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
		
        VERBOSE("dumping binary: preparing to dump");
        
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
		if (mach.flags & MH_PIE) {
            VERBOSE("dumping binary: ASLR enabled, identifying dump location dynamically");
			// perform checks on vm regions
			memory_object_name_t object;
			vm_region_basic_info_data_t info;
			mach_msg_type_number_t info_count = VM_REGION_BASIC_INFO_COUNT;
			vm_address_t region_start = 0;
			vm_size_t region_size = 0;
			vm_region_flavor_t flavor = VM_REGION_BASIC_INFO;
			err = 0;
			
			while (err == KERN_SUCCESS) {
				err = vm_region(port, &region_start, &region_size, flavor, (vm_region_info_t) &info, &info_count, &object);
				if (region_size == crypt.cryptsize) {
					break;
				}
				__text_start = region_start;
				region_start += region_size;
				region_size	= 0;
			}
			if (err != KERN_SUCCESS) {
				free(checksum);
				kill(pid, SIGKILL);
				return FALSE;
				printf("ASLR is enabled and we could not identify the decrypted memory region.\n");
			}
		}
		
        uint32_t headerProgress = sizeof(struct mach_header);
        uint32_t i_lcmd = 0;
        
        // overdrive dylib load command size
        uint32_t overdrive_size = sizeof(OVERDRIVE_DYLIB_PATH) + sizeof(struct dylib_command);
        overdrive_size += sizeof(long) - (overdrive_size % sizeof(long)); // load commands like to be aligned by long
        
        VERBOSE("dumping binary: performing dump");
        
		while (togo > 0) {
            // get a percentage for the progress bar
            PERCENT((int)ceil((((double)total - togo) / (double)total) * 100));
            
			// move an entire page into memory (we have to move an entire page regardless of whether it's a resultant or not)
			if((err = vm_read_overwrite(port, (mach_vm_address_t) __text_start + (pages_d * 0x1000), (vm_size_t) 0x1000, (pointer_t) buf, &local_size)) != KERN_SUCCESS)	{
                VERBOSE("dumping binary: failed to dump a page");
				free(checksum); // free checksum table
				kill(pid, SIGKILL); // kill fork
				return FALSE;
			}
			
			if (header) {
                // is this the first header page?
                if (i_lcmd == 0) {
                    // is overdrive enabled?
                    if (overdrive_enabled) {
                        // prepare the mach header for the new load command (overdrive dylib)
                        ((struct mach_header *)buf)->ncmds += 1;
                        ((struct mach_header *)buf)->sizeofcmds += overdrive_size;
                        VERBOSE("dumping binary: patched mach header (overdrive)");
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
                        vm_read_overwrite(port, (mach_vm_address_t) __text_start + ((pages_d+1) * 0x1000), (vm_size_t) 0x1, (pointer_t) &lcmd_size, &local_size);
                        //printf("ieterating through header\n");
                    } else {
                        lcmd_size = l_cmd->cmdsize;
                    }
                    
                    if (l_cmd->cmd == LC_ENCRYPTION_INFO) {
                        struct encryption_info_command *newcrypt = (struct encryption_info_command *) curloc;
                        newcrypt->cryptid = 0; // change the cryptid to 0
                        VERBOSE("dumping binary: patched cryptid");
                    } else if (l_cmd->cmd == LC_SEGMENT) {
                        //printf("lc segemn yo\n");
                        struct segment_command *newseg = (struct segment_command *) curloc;
                        if (newseg->fileoff == 0 && newseg->filesize > 0) {
                            // is overdrive enabled? this is __TEXT
                            if (overdrive_enabled) {
                                // maxprot so that overdrive can change the __TEXT protection &
                                // cryptid in realtime
                                newseg->maxprot |= VM_PROT_ALL;
                                VERBOSE("dumping binary: patched maxprot (overdrive)");
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
                if (overdrive_enabled) {
                    // add the overdrive dylib as long as we have room
                    if ((int8_t*)(curloc + overdrive_size) < (int8_t*)(buf + 0x1000)) {
                        VERBOSE("dumping binary: attaching overdrive DYLIB (overdrive)");
                        struct dylib_command *overdrive_dyld = (struct dylib_command *) curloc;
                        overdrive_dyld->cmd = LC_LOAD_DYLIB;
                        overdrive_dyld->cmdsize = overdrive_size;
                        overdrive_dyld->dylib.compatibility_version = OVERDRIVE_DYLIB_COMPATIBILITY_VERSION;
                        overdrive_dyld->dylib.current_version = OVERDRIVE_DYLIB_CURRENT_VER;
                        overdrive_dyld->dylib.timestamp = 2;
                        overdrive_dyld->dylib.name.offset = sizeof(struct dylib_command);
                        overdrive_dyld->dylib.name.ptr = (char *) sizeof(struct dylib_command);
                        
                        char *p = (char *) overdrive_dyld + overdrive_dyld->dylib.name.offset;
                        strncpy(p, OVERDRIVE_DYLIB_PATH, sizeof(OVERDRIVE_DYLIB_PATH));
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
        
        VERBOSE("dumping binary: writing new checksum");
		
		// nice! now let's write the new checksum data
		fseek(target, begin + CFSwapInt32(directory.hashOffset), SEEK_SET); // go to the hash offset
		fwrite(checksum, 20*pages_d, 1, target); // write the hashes (ONLY for the amount of pages modified)
		
		free(checksum); // free checksum table from memory
		kill(pid, SIGKILL); // kill the fork
	}
	stop_bar();
	return TRUE;
}

void sha1(uint8_t *hash, uint8_t *data, size_t size) {
	SHA1Context context;
	SHA1Reset(&context);
	SHA1Input(&context, data, size);
	SHA1Result(&context, hash);
}