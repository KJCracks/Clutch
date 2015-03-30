//
//  ARMDumper.m
//  Clutch
//
//  Created by Anton Titkov on 22.03.15.
//
//

#import "ARMDumper.h"
#import <mach-o/fat.h>
#import "Device.h"

@implementation ARMDumper

- (cpu_type_t)supportedCPUType
{
    return CPU_TYPE_ARM;
}


- (BOOL)dumpBinaryToURL:(NSURL *)newLocURL {
    
    FILE* newBinary = fopen(newLocURL.path.UTF8String, "r+");
    FILE* oldBinary = _originalBinary.binaryFile;
    
    NSString* swappedBinaryPath, *newSinf, *newSupp;
    
    //check if cpusubtype matches
    if (_thinHeader.header.cpusubtype != [Device cpu_subtype]) {
        //time to swap
        NSString* suffix = [NSString stringWithFormat:@"_%@", [Dumper readableArchFromHeader:_thinHeader]];
        
        swappedBinaryPath = [_originalBinary.binaryPath stringByAppendingString:suffix];
        newSinf = [_originalBinary.sinfPath stringByAppendingString:suffix];
        newSupp = [_originalBinary.supfPath stringByAppendingString:suffix];
        
        [[NSFileManager defaultManager] copyItemAtPath:_originalBinary.binaryPath toPath:swappedBinaryPath error:nil];
        [[NSFileManager defaultManager] copyItemAtPath:_originalBinary.sinfPath toPath:newSinf error:nil];
        [[NSFileManager defaultManager] copyItemAtPath:_originalBinary.sinfPath toPath:newSupp error:nil];
        
        fclose(oldBinary);
        oldBinary = fopen(swappedBinaryPath.UTF8String, "r+");
        
        char buffer[4096];
        
        fread(&buffer, sizeof(buffer), 1, oldBinary);
        
        struct fat_header* fh = (struct fat_header*) (buffer);
        struct fat_arch* arch = (struct fat_arch *) &fh[1];
        struct fat_arch copyArch;
        
        BOOL foundarch = FALSE;
        
        fseek(oldBinary, 8, SEEK_SET); //skip nfat_arch and bin_magic
        
        for (int i = 0; i < CFSwapInt32(fh->nfat_arch); i++)
        {
            if (arch->cpusubtype == _thinHeader.header.cpusubtype)
            {
                NSLog(@"found arch to keep %u! Storing it", CFSwapInt32(arch->cpusubtype));
                foundarch = TRUE;
                
                fread(&copyArch, sizeof(struct fat_arch), 1, oldBinary);
            }
            else
            {
                fseek(oldBinary, sizeof(struct fat_arch), SEEK_CUR);
            }
            
            arch++;
        }
        
        if (!foundarch)
        {
            NSLog(@"error: could not find arch to keep!");
            return false;
        }
        
        fseek(oldBinary, 8, SEEK_SET);
        fwrite(&copyArch, sizeof(struct fat_arch), 1, oldBinary);
        
        char data[20];
        
        memset(data,'\0',sizeof(data));
        
        for (int i = 0; i < (CFSwapInt32(fh->nfat_arch) - 1); i++)
        {
            NSLog(@"blanking arch! %u", i);
            fwrite(data, sizeof(data), 1, oldBinary);
        }
        
        //change nfat_arch
        NSLog(@"changing nfat_arch");
        
        uint32_t bin_nfat_arch = 0x1000000;
        
        //DEBUG(@"number of architectures %u", CFSwapInt32(bin_nfat_arch));
        
        fseek(oldBinary, 4, SEEK_SET); //bin_magic
        fwrite(&bin_nfat_arch, 4, 1, oldBinary);
        
        NSLog(@"wrote new header to binary");
        
    }
    //actual dumping
    
    fseek(newBinary, _thinHeader.offset, SEEK_SET); //seek to the start of the architecture
    
    struct linkedit_data_command ldid; // LC_CODE_SIGNATURE load header (for resign)
    struct encryption_info_command crypt; // LC_ENCRYPTION_INFO load header (for crypt*)
    struct mach_header mach; // generic mach header
    struct load_command l_cmd; // generic load command
    struct segment_command __text; // __TEXT segment
    
    struct SuperBlob *codesignblob; // codesign blob pointer
    //struct CodeDirectory directory; // codesign directory index
    
    BOOL foundCrypt = FALSE;
    BOOL foundSignature = FALSE;
    BOOL foundStartText = FALSE;
    
    uint32_t __text_start = 0;

    NSLog(@"32bit dumping: offset %u", _thinHeader.offset);
    
    //VERBOSE("dumping binary: analyzing load commands");
    fread(&mach, sizeof(struct mach_header), 1, newBinary); // read mach header to get number of load commands
    
    for (int lc_index = 0; lc_index < mach.ncmds; lc_index++) { // iterate over each load command
        fread(&l_cmd, sizeof(struct load_command), 1, newBinary); // read load command from binary
        if (l_cmd.cmd == LC_ENCRYPTION_INFO) { // encryption info?
            fseek(newBinary, -1 * sizeof(struct load_command), SEEK_CUR);
            fread(&crypt, sizeof(struct encryption_info_command), 1, newBinary);
            foundCrypt = TRUE; // remember that it was found
            NSLog(@"found encryption info");
        } else if (l_cmd.cmd == LC_CODE_SIGNATURE) { // code signature?
            fseek(newBinary, -1 * sizeof(struct load_command), SEEK_CUR);
            fread(&ldid, sizeof(struct linkedit_data_command), 1, newBinary);
            foundSignature = TRUE; // remember that it was found
            NSLog(@"found code signature");
        } else if (l_cmd.cmd == LC_SEGMENT) {
            // some applications, like Skype, have decided to start offsetting the executable image's
            // vm regions by substantial amounts for no apparant reason. this will find the vmaddr of
            // that segment (referenced later during dumping)
            fseek(newBinary, -1 * sizeof(struct load_command), SEEK_CUR);
            fread(&__text, sizeof(struct segment_command), 1, newBinary);
            
            if (strncmp(__text.segname, "__TEXT", 6) == 0) {
                foundStartText = TRUE;
                __text_start = __text.vmaddr;
                //__text_size = __text.vmsize; This has been a dead store since Clutch 1.0 I think
            }
            fseek(newBinary, l_cmd.cmdsize - sizeof(struct segment_command), SEEK_CUR);
            NSLog(@"found segment");
        } else {
            fseek(newBinary, l_cmd.cmdsize - sizeof(struct load_command), SEEK_CUR); // seek over the load command
        }
        
        if (foundCrypt && foundSignature && foundStartText)
            break;
    }
    
    // we need to have found both of these
    if (!foundCrypt || !foundSignature || !foundStartText) {
        NSLog("dumping binary: some load commands were not found");
        return FALSE;
    }
    
    return NO;
}

@end
