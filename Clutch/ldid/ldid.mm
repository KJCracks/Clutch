/* ldid - (Mach-O) Link-Loader Identity Editor
 * Copyright (C) 2007-2012  Jay Freeman (saurik)
*/

/* GNU Affero General Public License, Version 3 {{{ */
/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.

 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
**/
/* }}} */

#include "ldid_stdlib.h"
#include "ldid_string.h"
#include "ldid_mapping.h"
#include "ldid.h"

extern "C" {
#include "sha1.h"
}

#include <cstring>
#include <string>
#include <vector>

struct fat_header {
    uint32_t magic;
    uint32_t nfat_arch;
} _packed;

#define FAT_MAGIC 0xcafebabe
#define FAT_CIGAM 0xbebafeca

struct fat_arch {
    uint32_t cputype;
    uint32_t cpusubtype;
    uint32_t offset;
    uint32_t size;
    uint32_t align;
} _packed;

struct mach_header {
    uint32_t magic;
    uint32_t cputype;
    uint32_t cpusubtype;
    uint32_t filetype;
    uint32_t ncmds;
    uint32_t sizeofcmds;
    uint32_t flags;
} _packed;

#define MH_MAGIC 0xfeedface
#define MH_CIGAM 0xcefaedfe

#define MH_MAGIC_64 0xfeedfacf
#define MH_CIGAM_64 0xcffaedfe

#define MH_DYLDLINK   0x4

#define MH_OBJECT     0x1
#define MH_EXECUTE    0x2
#define MH_DYLIB      0x6
#define MH_BUNDLE     0x8
#define MH_DYLIB_STUB 0x9

struct load_command {
    uint32_t cmd;
    uint32_t cmdsize;
} _packed;

#define LC_REQ_DYLD           uint32_t(0x80000000)

#define LC_SEGMENT            uint32_t(0x01)
#define LC_SYMTAB             uint32_t(0x02)
#define LC_DYSYMTAB           uint32_t(0x0b)
#define LC_LOAD_DYLIB         uint32_t(0x0c)
#define LC_ID_DYLIB           uint32_t(0x0d)
#define LC_SEGMENT_64         uint32_t(0x19)
#define LC_UUID               uint32_t(0x1b)
#define LC_CODE_SIGNATURE     uint32_t(0x1d)
#define LC_SEGMENT_SPLIT_INFO uint32_t(0x1e)
#define LC_REEXPORT_DYLIB     uint32_t(0x1f | LC_REQ_DYLD)
#define LC_ENCRYPTION_INFO    uint32_t(0x21)
#define LC_DYLD_INFO          uint32_t(0x22)
#define LC_DYLD_INFO_ONLY     uint32_t(0x22 | LC_REQ_DYLD)

struct dylib {
    uint32_t name;
    uint32_t timestamp;
    uint32_t current_version;
    uint32_t compatibility_version;
} _packed;

struct dylib_command {
    uint32_t cmd;
    uint32_t cmdsize;
    struct dylib dylib;
} _packed;

struct uuid_command {
    uint32_t cmd;
    uint32_t cmdsize;
    uint8_t uuid[16];
} _packed;

struct symtab_command {
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t symoff;
    uint32_t nsyms;
    uint32_t stroff;
    uint32_t strsize;
} _packed;

struct dyld_info_command {
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t rebase_off;
    uint32_t rebase_size;
    uint32_t bind_off;
    uint32_t bind_size;
    uint32_t weak_bind_off;
    uint32_t weak_bind_size;
    uint32_t lazy_bind_off;
    uint32_t lazy_bind_size;
    uint32_t export_off;
    uint32_t export_size;
} _packed;

struct dysymtab_command {
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t ilocalsym;
    uint32_t nlocalsym;
    uint32_t iextdefsym;
    uint32_t nextdefsym;
    uint32_t iundefsym;
    uint32_t nundefsym;
    uint32_t tocoff;
    uint32_t ntoc;
    uint32_t modtaboff;
    uint32_t nmodtab;
    uint32_t extrefsymoff;
    uint32_t nextrefsyms;
    uint32_t indirectsymoff;
    uint32_t nindirectsyms;
    uint32_t extreloff;
    uint32_t nextrel;
    uint32_t locreloff;
    uint32_t nlocrel;
} _packed;

struct dylib_table_of_contents {
    uint32_t symbol_index;
    uint32_t module_index;
} _packed;

struct dylib_module {
    uint32_t module_name;
    uint32_t iextdefsym;
    uint32_t nextdefsym;
    uint32_t irefsym;
    uint32_t nrefsym;
    uint32_t ilocalsym;
    uint32_t nlocalsym;
    uint32_t iextrel;
    uint32_t nextrel;
    uint32_t iinit_iterm;
    uint32_t ninit_nterm;
    uint32_t objc_module_info_addr;
    uint32_t objc_module_info_size;
} _packed;

struct dylib_reference {
    uint32_t isym:24;
    uint32_t flags:8;
} _packed;

struct relocation_info {
    int32_t r_address;
    uint32_t r_symbolnum:24;
    uint32_t r_pcrel:1;
    uint32_t r_length:2;
    uint32_t r_extern:1;
    uint32_t r_type:4;
} _packed;

struct nlist {
    union {
        char *n_name;
        int32_t n_strx;
    } n_un;

    uint8_t n_type;
    uint8_t n_sect;
    uint8_t n_desc;
    uint32_t n_value;
} _packed;

struct segment_command {
    uint32_t cmd;
    uint32_t cmdsize;
    char segname[16];
    uint32_t vmaddr;
    uint32_t vmsize;
    uint32_t fileoff;
    uint32_t filesize;
    uint32_t maxprot;
    uint32_t initprot;
    uint32_t nsects;
    uint32_t flags;
} _packed;

struct segment_command_64 {
    uint32_t cmd;
    uint32_t cmdsize;
    char segname[16];
    uint64_t vmaddr;
    uint64_t vmsize;
    uint64_t fileoff;
    uint64_t filesize;
    uint32_t maxprot;
    uint32_t initprot;
    uint32_t nsects;
    uint32_t flags;
} _packed;

struct section {
    char sectname[16];
    char segname[16];
    uint32_t addr;
    uint32_t size;
    uint32_t offset;
    uint32_t align;
    uint32_t reloff;
    uint32_t nreloc;
    uint32_t flags;
    uint32_t reserved1;
    uint32_t reserved2;
} _packed;

struct section_64 {
    char sectname[16];
    char segname[16];
    uint64_t addr;
    uint64_t size;
    uint32_t offset;
    uint32_t align;
    uint32_t reloff;
    uint32_t nreloc;
    uint32_t flags;
    uint32_t reserved1;
    uint32_t reserved2;
} _packed;

struct linkedit_data_command {
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t dataoff;
    uint32_t datasize;
} _packed;

struct encryption_info_command {
    uint32_t cmd;
    uint32_t cmdsize;
    uint32_t cryptoff;
    uint32_t cryptsize;
    uint32_t cryptid;
} _packed;

#define BIND_OPCODE_MASK                             0xf0
#define BIND_IMMEDIATE_MASK                          0x0f
#define BIND_OPCODE_DONE                             0x00
#define BIND_OPCODE_SET_DYLIB_ORDINAL_IMM            0x10
#define BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB           0x20
#define BIND_OPCODE_SET_DYLIB_SPECIAL_IMM            0x30
#define BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM    0x40
#define BIND_OPCODE_SET_TYPE_IMM                     0x50
#define BIND_OPCODE_SET_ADDEND_SLEB                  0x60
#define BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB      0x70
#define BIND_OPCODE_ADD_ADDR_ULEB                    0x80
#define BIND_OPCODE_DO_BIND                          0x90
#define BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB            0xa0
#define BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED      0xb0
#define BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB 0xc0

template <typename Type_>
Type_ Align(Type_ value, size_t align) {
    value += align - 1;
    value /= align;
    value *= align;
    return value;
}

uint16_t Swap_(uint16_t value) {
    return
        ((value >>  8) & 0x00ff) |
        ((value <<  8) & 0xff00);
}

uint32_t Swap_(uint32_t value) {
    value = ((value >>  8) & 0x00ff00ff) |
            ((value <<  8) & 0xff00ff00);
    value = ((value >> 16) & 0x0000ffff) |
            ((value << 16) & 0xffff0000);
    return value;
}

uint64_t Swap_(uint64_t value) {
    value = (value & 0x00000000ffffffff) << 32 | (value & 0xffffffff00000000) >> 32;
    value = (value & 0x0000ffff0000ffff) << 16 | (value & 0xffff0000ffff0000) >> 16;
    value = (value & 0x00ff00ff00ff00ff) << 8  | (value & 0xff00ff00ff00ff00) >> 8;
    return value;
}

int16_t Swap_(int16_t value) {
    return Swap_(static_cast<uint16_t>(value));
}

int32_t Swap_(int32_t value) {
    return Swap_(static_cast<uint32_t>(value));
}

int64_t Swap_(int64_t value) {
    return Swap_(static_cast<uint64_t>(value));
}

bool little_(true);

uint16_t Swap(uint16_t value) {
    return little_ ? Swap_(value) : value;
}

uint32_t Swap(uint32_t value) {
    return little_ ? Swap_(value) : value;
}

uint64_t Swap(uint64_t value) {
    return little_ ? Swap_(value) : value;
}

int16_t Swap(int16_t value) {
    return Swap(static_cast<uint16_t>(value));
}

int32_t Swap(int32_t value) {
    return Swap(static_cast<uint32_t>(value));
}

int64_t Swap(int64_t value) {
    return Swap(static_cast<uint64_t>(value));
}

template <typename Target_>
class Pointer;

class Data {
  private:
    void *base_;
    size_t size_;

  protected:
    bool swapped_;

  public:
    Data(void *base, size_t size) :
        base_(base),
        size_(size),
        swapped_(false)
    {
    }

    uint16_t Swap(uint16_t value) const {
        return swapped_ ? Swap_(value) : value;
    }

    uint32_t Swap(uint32_t value) const {
        return swapped_ ? Swap_(value) : value;
    }

    uint64_t Swap(uint64_t value) const {
        return swapped_ ? Swap_(value) : value;
    }

    int16_t Swap(int16_t value) const {
        return Swap(static_cast<uint16_t>(value));
    }

    int32_t Swap(int32_t value) const {
        return Swap(static_cast<uint32_t>(value));
    }

    int64_t Swap(int64_t value) const {
        return Swap(static_cast<uint64_t>(value));
    }

    void *GetBase() const {
        return base_;
    }

    size_t GetSize() const {
        return size_;
    }
};

class MachHeader :
    public Data
{
  private:
    bool bits64_;

    struct mach_header *mach_header_;
    struct load_command *load_command_;

  public:
    MachHeader(void *base, size_t size) :
        Data(base, size)
    {
        mach_header_ = (mach_header *) base;

        switch (Swap(mach_header_->magic)) {
            case MH_CIGAM:
                swapped_ = !swapped_;
            case MH_MAGIC:
                bits64_ = false;
            break;

            case MH_CIGAM_64:
                swapped_ = !swapped_;
            case MH_MAGIC_64:
                bits64_ = true;
            break;

            default:
                _assert(false);
        }

        void *post = mach_header_ + 1;
        if (bits64_)
            post = (uint32_t *) post + 1;
        load_command_ = (struct load_command *) post;

        _assert(
            Swap(mach_header_->filetype) == MH_EXECUTE ||
            Swap(mach_header_->filetype) == MH_DYLIB ||
            Swap(mach_header_->filetype) == MH_BUNDLE
        );
    }

    struct mach_header *operator ->() const {
        return mach_header_;
    }

    operator struct mach_header *() const {
        return mach_header_;
    }

    uint32_t GetCPUType() const {
        return Swap(mach_header_->cputype);
    }

    uint32_t GetCPUSubtype() const {
        return Swap(mach_header_->cpusubtype) & 0xff;
    }

    struct load_command *GetLoadCommand() const {
        return load_command_;
    }

    std::vector<struct load_command *> GetLoadCommands() const {
        std::vector<struct load_command *> load_commands;

        struct load_command *load_command = load_command_;
        for (uint32_t cmd = 0; cmd != Swap(mach_header_->ncmds); ++cmd) {
            load_commands.push_back(load_command);
            load_command = (struct load_command *) ((uint8_t *) load_command + Swap(load_command->cmdsize));
        }

        return load_commands;
    }

    std::vector<segment_command *> GetSegments(const char *segment_name) const {
        std::vector<struct segment_command *> segment_commands;

        _foreach (load_command, GetLoadCommands()) {
            if (Swap(load_command->cmd) == LC_SEGMENT) {
                segment_command *segment_command = reinterpret_cast<struct segment_command *>(load_command);
                if (strncmp(segment_command->segname, segment_name, 16) == 0)
                    segment_commands.push_back(segment_command);
            }
        }

        return segment_commands;
    }

    std::vector<segment_command_64 *> GetSegments64(const char *segment_name) const {
        std::vector<struct segment_command_64 *> segment_commands;

        _foreach (load_command, GetLoadCommands()) {
            if (Swap(load_command->cmd) == LC_SEGMENT_64) {
                segment_command_64 *segment_command = reinterpret_cast<struct segment_command_64 *>(load_command);
                if (strncmp(segment_command->segname, segment_name, 16) == 0)
                    segment_commands.push_back(segment_command);
            }
        }

        return segment_commands;
    }

    std::vector<section *> GetSections(const char *segment_name, const char *section_name) const {
        std::vector<section *> sections;

        _foreach (segment, GetSegments(segment_name)) {
            section *section = (struct section *) (segment + 1);

            uint32_t sect;
            for (sect = 0; sect != Swap(segment->nsects); ++sect) {
                if (strncmp(section->sectname, section_name, 16) == 0)
                    sections.push_back(section);
                ++section;
            }
        }

        return sections;
    }

    template <typename Target_>
    Pointer<Target_> GetPointer(uint32_t address, const char *segment_name = NULL) const {
        load_command *load_command = (struct load_command *) (mach_header_ + 1);
        uint32_t cmd;

        for (cmd = 0; cmd != Swap(mach_header_->ncmds); ++cmd) {
            if (Swap(load_command->cmd) == LC_SEGMENT) {
                segment_command *segment_command = (struct segment_command *) load_command;
                if (segment_name != NULL && strncmp(segment_command->segname, segment_name, 16) != 0)
                    goto next_command;

                section *sections = (struct section *) (segment_command + 1);

                uint32_t sect;
                for (sect = 0; sect != Swap(segment_command->nsects); ++sect) {
                    section *section = &sections[sect];
                    //printf("%s %u %p %p %u\n", segment_command->segname, sect, address, section->addr, section->size);
                    if (address >= Swap(section->addr) && address < Swap(section->addr) + Swap(section->size)) {
                        //printf("0x%.8x %s\n", address, segment_command->segname);
                        return Pointer<Target_>(this, reinterpret_cast<Target_ *>(address - Swap(section->addr) + Swap(section->offset) + (char *) mach_header_));
                    }
                }
            }

          next_command:
            load_command = (struct load_command *) ((char *) load_command + Swap(load_command->cmdsize));
        }

        return Pointer<Target_>(this);
    }

    template <typename Target_>
    Pointer<Target_> GetOffset(uint32_t offset) {
        return Pointer<Target_>(this, reinterpret_cast<Target_ *>(offset + (uint8_t *) mach_header_));
    }
};

class FatMachHeader :
    public MachHeader
{
  private:
    fat_arch *fat_arch_;

  public:
    FatMachHeader(void *base, size_t size, fat_arch *fat_arch) :
        MachHeader(base, size),
        fat_arch_(fat_arch)
    {
    }

    fat_arch *GetFatArch() const {
        return fat_arch_;
    }
};

class FatHeader :
    public Data
{
  private:
    fat_header *fat_header_;
    std::vector<FatMachHeader> mach_headers_;

  public:
    FatHeader(void *base, size_t size) :
        Data(base, size)
    {
        fat_header_ = reinterpret_cast<struct fat_header *>(base);

        if (Swap(fat_header_->magic) == FAT_CIGAM) {
            swapped_ = !swapped_;
            goto fat;
        } else if (Swap(fat_header_->magic) != FAT_MAGIC) {
            fat_header_ = NULL;
            mach_headers_.push_back(FatMachHeader(base, size, NULL));
        } else fat: {
            size_t fat_narch = Swap(fat_header_->nfat_arch);
            fat_arch *fat_arch = reinterpret_cast<struct fat_arch *>(fat_header_ + 1);
            size_t arch;
            for (arch = 0; arch != fat_narch; ++arch) {
                uint32_t arch_offset = Swap(fat_arch->offset);
                uint32_t arch_size = Swap(fat_arch->size);
                mach_headers_.push_back(FatMachHeader((uint8_t *) base + arch_offset, arch_size, fat_arch));
                ++fat_arch;
            }
        }
    }

    std::vector<FatMachHeader> &GetMachHeaders() {
        return mach_headers_;
    }

    bool IsFat() const {
        return fat_header_ != NULL;
    }

    struct fat_header *operator ->() const {
        return fat_header_;
    }

    operator struct fat_header *() const {
        return fat_header_;
    }
};

FatHeader Map(const char *path, bool ro = false) {
    size_t size;
    void *base(map(path, 0, _not(size_t), &size, ro));
    return FatHeader(base, size);
}

template <typename Target_>
class Pointer {
  private:
    const MachHeader *framework_;
    const Target_ *pointer_;

  public:
    Pointer(const MachHeader *framework = NULL, const Target_ *pointer = NULL) :
        framework_(framework),
        pointer_(pointer)
    {
    }

    operator const Target_ *() const {
        return pointer_;
    }

    const Target_ *operator ->() const {
        return pointer_;
    }

    Pointer<Target_> &operator ++() {
        ++pointer_;
        return *this;
    }

    template <typename Value_>
    Value_ Swap(Value_ value) {
        return framework_->Swap(value);
    }
};

#define CSMAGIC_CODEDIRECTORY      uint32_t(0xfade0c02)
#define CSMAGIC_EMBEDDED_SIGNATURE uint32_t(0xfade0cc0)
#define CSMAGIC_ENTITLEMENTS       uint32_t(0xfade7171)

#define CSSLOT_CODEDIRECTORY uint32_t(0)
#define CSSLOT_REQUIREMENTS  uint32_t(2)
#define CSSLOT_ENTITLEMENTS  uint32_t(5)

struct BlobIndex {
    uint32_t type;
    uint32_t offset;
} _packed;

struct Blob {
    uint32_t magic;
    uint32_t length;
} _packed;

struct SuperBlob {
    struct Blob blob;
    uint32_t count;
    struct BlobIndex index[];
} _packed;

struct CodeDirectory {
    struct Blob blob;
    uint32_t version;
    uint32_t flags;
    uint32_t hashOffset;
    uint32_t identOffset;
    uint32_t nSpecialSlots;
    uint32_t nCodeSlots;
    uint32_t codeLimit;
    uint8_t hashSize;
    uint8_t hashType;
    uint8_t spare1;
    uint8_t pageSize;
    uint32_t spare2;
} _packed;

extern "C" uint32_t hash(uint8_t *k, uint32_t length, uint32_t initval);

void sha1(uint8_t *hash, uint8_t *data, size_t size) {
    SHA1Context context;
    SHA1Reset(&context);
    SHA1Input(&context, data, size);
    SHA1Result(&context, hash);
}

struct CodesignAllocation {
    FatMachHeader mach_header_;
    uint32_t offset_;
    uint32_t size_;
    uint32_t alloc_;
    uint32_t align_;

    CodesignAllocation(FatMachHeader mach_header, size_t offset, size_t size, size_t alloc, size_t align) :
        mach_header_(mach_header),
        offset_(offset),
        size_(size),
        alloc_(alloc),
        align_(align)
    {
    }
};

int ldid_main(int argc, const char *argv[],FILE *entitlementsFile) {
    union {
        uint16_t word;
        uint8_t byte[2];
    } endian = {1};

    little_ = endian.byte[0];

    bool flag_R(false);
    bool flag_r(false);

    bool flag_t(false);
    bool flag_p(false);
    bool flag_u(false);
    bool flag_e(false);

    bool flag_T(false);

    bool flag_S(false);
    bool flag_s(false);

    bool flag_O(false);

    bool flag_D(false);
    bool flag_d(false);

    bool flag_A(false);
    bool flag_a(false);

    uint32_t flag_CPUType(_not(uint32_t));
    uint32_t flag_CPUSubtype(_not(uint32_t));

    const char *flag_I(NULL);

    bool timeh(false);
    uint32_t timev(0);

    const void *xmld(NULL);
    size_t xmls(0);

    uintptr_t noffset(_not(uintptr_t));
    uintptr_t woffset(_not(uintptr_t));

    std::vector<std::string> files;

    if (argc == 1) {
        fprintf(stderr, "usage: %s -S[entitlements.xml] <binary>\n", argv[0]);
        fprintf(stderr, "   %s -e MobileSafari\n", argv[0]);
        fprintf(stderr, "   %s -S cat\n", argv[0]);
        fprintf(stderr, "   %s -Stfp.xml gdb\n", argv[0]);
        exit(0);
    }

    for (int argi(1); argi != argc; ++argi)
        if (argv[argi][0] != '-')
            files.push_back(argv[argi]);
        else switch (argv[argi][1]) {
            case 'R': flag_R = true; break;
            case 'r': flag_r = true; break;

            case 't': flag_t = true; break;
            case 'u': flag_u = true; break;
            case 'p': flag_p = true; break;
            case 'e': flag_e = true; break;
            case 'O': flag_O = true; break;

            case 'D': flag_D = true; break;
            case 'd': flag_d = true; break;

            case 'a': flag_a = true; break;

            case 'A':
                flag_A = true;
                if (argv[argi][2] != '\0') {
                    const char *cpu = argv[argi] + 2;
                    const char *colon = strchr(cpu, ':');
                    _assert(colon != NULL);
                    char *arge;
                    flag_CPUType = strtoul(cpu, &arge, 0);
                    _assert(arge == colon);
                    flag_CPUSubtype = strtoul(colon + 1, &arge, 0);
                    _assert(arge == argv[argi] + strlen(argv[argi]));
                }
            break;

            case 's':
                _assert(!flag_S);
                flag_s = true;
            break;

            case 'S':
                _assert(!flag_s);
                flag_S = true;
                if (argv[argi][2] != '\0') {
                    const char *xml = argv[argi] + 2;
                    xmld = map(xml, 0, _not(size_t), &xmls, true);
                }
            break;

            case 'T': {
                flag_T = true;
                if (argv[argi][2] == '-')
                    timeh = true;
                else {
                    char *arge;
                    timev = strtoul(argv[argi] + 2, &arge, 0);
                    _assert(arge == argv[argi] + strlen(argv[argi]));
                }
            } break;

            case 'I': {
                flag_I = argv[argi] + 2;
            } break;

            case 'n': {
                char *arge;
                noffset = strtoul(argv[argi] + 2, &arge, 0);
                _assert(arge == argv[argi] + strlen(argv[argi]));
            } break;

            case 'w': {
                char *arge;
                woffset = strtoul(argv[argi] + 2, &arge, 0);
                _assert(arge == argv[argi] + strlen(argv[argi]));
            } break;

            default:
                goto usage;
            break;
        }

    if (files.empty()) usage: {
        exit(0);
    }

    size_t filei(0), filee(0);
    _foreach (file, files) try {
        const char *path(file.c_str());
        const char *base = strrchr(path, '/');
        char *temp(NULL), *dir;

        if (base != NULL)
            dir = strndup_(path, base++ - path + 1);
        else {
            dir = strdup("");
            base = path;
        }

        const char *name(flag_I ?: base);

        if (flag_r) {
            uint32_t clip(0); {
                FatHeader fat_header(Map(path));
                _foreach (mach_header, fat_header.GetMachHeaders()) {
                    if (flag_A) {
                        if (mach_header.GetCPUType() != flag_CPUType)
                            continue;
                        if (mach_header.GetCPUSubtype() != flag_CPUSubtype)
                            continue;
                    }

                    mach_header->flags = mach_header.Swap(mach_header.Swap(mach_header->flags) | MH_DYLDLINK);

                    uint32_t size(_not(uint32_t)); {
                        _foreach (load_command, mach_header.GetLoadCommands()) {
                            switch (mach_header.Swap(load_command->cmd)) {
                                case LC_CODE_SIGNATURE: {
                                    struct linkedit_data_command *signature = reinterpret_cast<struct linkedit_data_command *>(load_command);
                                    memset(reinterpret_cast<uint8_t *>(mach_header.GetBase()) + mach_header.Swap(signature->dataoff), 0, mach_header.Swap(signature->datasize));
                                    memset(signature, 0, sizeof(struct linkedit_data_command));

                                    mach_header->ncmds = mach_header.Swap(mach_header.Swap(mach_header->ncmds) - 1);
                                    mach_header->sizeofcmds = mach_header.Swap(uint32_t(mach_header.Swap(mach_header->sizeofcmds) - sizeof(struct linkedit_data_command)));
                                } break;

                                case LC_SYMTAB: {
                                    struct symtab_command *symtab = reinterpret_cast<struct symtab_command *>(load_command);
                                    size = mach_header.Swap(symtab->stroff) + mach_header.Swap(symtab->strsize);
                                } break;
                            }
                        }
                    }

                    _assert(size != _not(uint32_t));

                    _foreach (segment, mach_header.GetSegments("__LINKEDIT")) {
                        segment->filesize -= mach_header.GetSize() - size;

                        if (fat_arch *fat_arch = mach_header.GetFatArch()) {
                            fat_arch->size = fat_header.Swap(size);
                            clip = std::max(clip, fat_header.Swap(fat_arch->offset) + size);
                        } else
                            clip = std::max(clip, size);
                    }

                    _foreach (segment, mach_header.GetSegments64("__LINKEDIT")) {
                        segment->filesize -= mach_header.GetSize() - size;

                        if (fat_arch *fat_arch = mach_header.GetFatArch()) {
                            fat_arch->size = fat_header.Swap(size);
                            clip = std::max(clip, fat_header.Swap(fat_arch->offset) + size);
                        } else
                            clip = std::max(clip, size);
                    }
                }
            }

            if (clip != 0)
                _syscall(truncate(path, clip));
        }

        if (flag_S) {
            FatHeader source(Map(path));

            size_t offset(0);

            if (source.IsFat())
                offset += sizeof(fat_header) + sizeof(fat_arch) * source.Swap(source->nfat_arch);

            std::vector<CodesignAllocation> allocations; {
                _foreach (mach_header, source.GetMachHeaders()) {
                    if (flag_A) {
                        if (mach_header.GetCPUType() != flag_CPUType)
                            continue;
                        if (mach_header.GetCPUSubtype() != flag_CPUSubtype)
                            continue;
                    }

                    mach_header->flags = mach_header.Swap(mach_header.Swap(mach_header->flags) | MH_DYLDLINK);

                    size_t size(_not(size_t)); {
                        _foreach (load_command, mach_header.GetLoadCommands()) {
                            uint32_t cmd(mach_header.Swap(load_command->cmd));
                            if (cmd == LC_CODE_SIGNATURE) {
                                struct linkedit_data_command *signature = reinterpret_cast<struct linkedit_data_command *>(load_command);
                                size = mach_header.Swap(signature->dataoff);
                                _assert(size < mach_header.GetSize());
                                break;
                            }
                        }

                        if (size == _not(size_t))
                            size = mach_header.GetSize();
                    }

                    size_t alloc(0);
                    alloc += sizeof(struct SuperBlob);
                    uint32_t special(0);

                    special = std::max(special, CSSLOT_CODEDIRECTORY);
                    alloc += sizeof(struct BlobIndex);
                    alloc += sizeof(struct CodeDirectory);
                    alloc += strlen(name) + 1;

                    special = std::max(special, CSSLOT_REQUIREMENTS);
                    alloc += sizeof(struct BlobIndex);
                    alloc += 0xc;

                    if (xmld != NULL) {
                        special = std::max(special, CSSLOT_ENTITLEMENTS);
                        alloc += sizeof(struct BlobIndex);
                        alloc += sizeof(struct Blob);
                        alloc += xmls;
                    }

                    size_t normal((size + 0x1000 - 1) / 0x1000);
                    alloc = Align(alloc + (special + normal) * 0x14, 16);

                    auto *fat_arch(mach_header.GetFatArch());
                    uint32_t align(fat_arch == NULL ? 0 : source.Swap(fat_arch->align));
                    offset = Align(offset, 1 << align);

                    allocations.push_back(CodesignAllocation(mach_header, offset, size, alloc, align));
                    offset += size + alloc;
                    offset = Align(offset, 16);
                }
            }

            asprintf(&temp, "%s.%s.cs", dir, base);
            fclose(fopen(temp, "w+"));
            _syscall(truncate(temp, offset));

            void *file(map(temp, 0, offset, NULL, false));
            memset(file, 0, offset);

            fat_arch *fat_arch;
            if (!source.IsFat())
                fat_arch = NULL;
            else {
                auto *fat_header(reinterpret_cast<struct fat_header *>(file));
                fat_header->magic = Swap(FAT_MAGIC);
                fat_header->nfat_arch = Swap(source.Swap(source->nfat_arch));
                fat_arch = reinterpret_cast<struct fat_arch *>(fat_header + 1);
            }

            _foreach (allocation, allocations) {
                auto &source(allocation.mach_header_);

                uint32_t align(allocation.size_);
                align = Align(align, 0x10);

                if (fat_arch != NULL) {
                    fat_arch->cputype = Swap(source->cputype);
                    fat_arch->cpusubtype = Swap(source->cpusubtype);
                    fat_arch->offset = Swap(allocation.offset_);
                    fat_arch->size = Swap(align + allocation.alloc_);
                    fat_arch->align = Swap(allocation.align_);
                    ++fat_arch;
                }

                void *target(reinterpret_cast<uint8_t *>(file) + allocation.offset_);
                memcpy(target, source, allocation.size_);
                MachHeader mach_header(target, align + allocation.alloc_);

                struct linkedit_data_command *signature(NULL);
                _foreach (load_command, mach_header.GetLoadCommands()) {
                    uint32_t cmd(mach_header.Swap(load_command->cmd));
                    if (cmd != LC_CODE_SIGNATURE)
                        continue;
                    signature = reinterpret_cast<struct linkedit_data_command *>(load_command);
                    break;
                }

                if (signature == NULL) {
                    mach_header->ncmds = mach_header.Swap(mach_header.Swap(mach_header->ncmds) + 1);
                    signature = reinterpret_cast<struct linkedit_data_command *>(reinterpret_cast<uint8_t *>(mach_header.GetLoadCommand()) + mach_header.Swap(mach_header->sizeofcmds));
                    mach_header->sizeofcmds = mach_header.Swap(mach_header.Swap(mach_header->sizeofcmds) + uint32_t(sizeof(*signature)));
                    signature->cmd = mach_header.Swap(LC_CODE_SIGNATURE);
                    signature->cmdsize = mach_header.Swap(uint32_t(sizeof(*signature)));
                }

                signature->dataoff = mach_header.Swap(align);
                signature->datasize = mach_header.Swap(allocation.alloc_);

                _foreach (segment, mach_header.GetSegments("__LINKEDIT")) {
                    size_t size(mach_header.Swap(align + allocation.alloc_ - mach_header.Swap(segment->fileoff)));
                    segment->filesize = size;
                    segment->vmsize = Align(size, 0x1000);
                }

                _foreach (segment, mach_header.GetSegments64("__LINKEDIT")) {
                    size_t size(mach_header.Swap(align + allocation.alloc_ - mach_header.Swap(segment->fileoff)));
                    segment->filesize = size;
                    segment->vmsize = Align(size, 0x1000);
                }
            }
        }

        if (flag_p)
            printf("path%zu='%s'\n", filei, file.c_str());

        FatHeader fat_header(Map(temp == NULL ? path : temp, !(flag_R || flag_T || flag_s || flag_S || flag_O || flag_D)));
        struct linkedit_data_command *signature(NULL);

        _foreach (mach_header, fat_header.GetMachHeaders()) {
            if (flag_A) {
                if (mach_header.GetCPUType() != flag_CPUType)
                    continue;
                if (mach_header.GetCPUSubtype() != flag_CPUSubtype)
                    continue;
            }

            if (flag_a)
                printf("cpu=0x%x:0x%x\n", mach_header.GetCPUType(), mach_header.GetCPUSubtype());

            if (flag_d) {
                if (struct fat_arch *fat_arch = mach_header.GetFatArch())
                    printf("offset=0x%x\n", Swap(fat_arch->offset));
                else
                    printf("offset=0x0\n");
            }

            if (woffset != _not(uintptr_t)) {
                Pointer<uint32_t> wvalue(mach_header.GetPointer<uint32_t>(woffset));
                if (wvalue == NULL)
                    printf("(null) %p\n", reinterpret_cast<void *>(woffset));
                else
                    printf("0x%.08x\n", *wvalue);
            }

            if (noffset != _not(uintptr_t))
                printf("%s\n", &*mach_header.GetPointer<char>(noffset));

            if (flag_d)
                _foreach(segment, mach_header.GetSegments("__TEXT")) {
                    printf("vmaddr=0x%x\n", mach_header.Swap(segment->vmaddr));
                    printf("fileoff=0x%x\n", mach_header.Swap(segment->fileoff));
                }

            if (flag_O) {
                _foreach(section, mach_header.GetSections("__TEXT", "__text"))
                    section->addr = mach_header.Swap(0);
            }

            _foreach (load_command, mach_header.GetLoadCommands()) {
                uint32_t cmd(mach_header.Swap(load_command->cmd));

                if (flag_R && cmd == LC_REEXPORT_DYLIB)
                    load_command->cmd = mach_header.Swap(LC_LOAD_DYLIB);
                else if (cmd == LC_CODE_SIGNATURE)
                    signature = reinterpret_cast<struct linkedit_data_command *>(load_command);
                else if (cmd == LC_UUID) {
                    volatile struct uuid_command *uuid_command(reinterpret_cast<struct uuid_command *>(load_command));

                    if (flag_u) {
                        printf("uuid%zu=%.2x%.2x%.2x%.2x-%.2x%.2x-%.2x%.2x-%.2x%.2x-%.2x%.2x%.2x%.2x%.2x%.2x\n", filei,
                            uuid_command->uuid[ 0], uuid_command->uuid[ 1], uuid_command->uuid[ 2], uuid_command->uuid[ 3],
                            uuid_command->uuid[ 4], uuid_command->uuid[ 5], uuid_command->uuid[ 6], uuid_command->uuid[ 7],
                            uuid_command->uuid[ 8], uuid_command->uuid[ 9], uuid_command->uuid[10], uuid_command->uuid[11],
                            uuid_command->uuid[12], uuid_command->uuid[13], uuid_command->uuid[14], uuid_command->uuid[15]
                        );
                    }
                } else if (cmd == LC_ID_DYLIB) {
                    volatile struct dylib_command *dylib_command(reinterpret_cast<struct dylib_command *>(load_command));

                    if (flag_t)
                        printf("time%zu=0x%.8x\n", filei, mach_header.Swap(dylib_command->dylib.timestamp));

                    if (flag_T) {
                        uint32_t timed;

                        if (!timeh)
                            timed = timev;
                        else {
                            dylib_command->dylib.timestamp = 0;
                            timed = hash(reinterpret_cast<uint8_t *>(mach_header.GetBase()), mach_header.GetSize(), timev);
                        }

                        dylib_command->dylib.timestamp = mach_header.Swap(timed);
                    }
                } else if (cmd == LC_ENCRYPTION_INFO) {
                    volatile struct encryption_info_command *encryption_info_command(reinterpret_cast<struct encryption_info_command *>(load_command));

                    if (flag_D)
                        encryption_info_command->cryptid = mach_header.Swap(0);

                    if (flag_d) {
                        printf("cryptoff=0x%x\n", mach_header.Swap(encryption_info_command->cryptoff));
                        printf("cryptsize=0x%x\n", mach_header.Swap(encryption_info_command->cryptsize));
                        printf("cryptid=0x%x\n", mach_header.Swap(encryption_info_command->cryptid));
                    }
                }
            }

            if (flag_e) {
                _assert(signature != NULL);

                uint32_t data = mach_header.Swap(signature->dataoff);

                uint8_t *top = reinterpret_cast<uint8_t *>(mach_header.GetBase());
                uint8_t *blob = top + data;
                struct SuperBlob *super = reinterpret_cast<struct SuperBlob *>(blob);

                for (size_t index(0); index != Swap(super->count); ++index)
                    if (Swap(super->index[index].type) == CSSLOT_ENTITLEMENTS) {
                        uint32_t begin = Swap(super->index[index].offset);
                        struct Blob *entitlements = reinterpret_cast<struct Blob *>(blob + begin);
                        fwrite(entitlements + 1, 1, Swap(entitlements->length) - sizeof(struct Blob), entitlementsFile);
                        return 0;
                    }
            }

            if (flag_s) {
                _assert(signature != NULL);

                uint32_t data = mach_header.Swap(signature->dataoff);

                uint8_t *top = reinterpret_cast<uint8_t *>(mach_header.GetBase());
                uint8_t *blob = top + data;
                struct SuperBlob *super = reinterpret_cast<struct SuperBlob *>(blob);

                for (size_t index(0); index != Swap(super->count); ++index)
                    if (Swap(super->index[index].type) == CSSLOT_CODEDIRECTORY) {
                        uint32_t begin = Swap(super->index[index].offset);
                        struct CodeDirectory *directory = reinterpret_cast<struct CodeDirectory *>(blob + begin);

                        uint8_t (*hashes)[20] = reinterpret_cast<uint8_t (*)[20]>(blob + begin + Swap(directory->hashOffset));
                        uint32_t pages = Swap(directory->nCodeSlots);

                        if (pages != 1)
                            for (size_t i = 0; i != pages - 1; ++i)
                                sha1(hashes[i], top + 0x1000 * i, 0x1000);
                        if (pages != 0)
                            sha1(hashes[pages - 1], top + 0x1000 * (pages - 1), ((data - 1) % 0x1000) + 1);
                    }
            }

            if (flag_S) {
                _assert(signature != NULL);

                uint32_t data = mach_header.Swap(signature->dataoff);
                uint32_t size = mach_header.Swap(signature->datasize);

                uint8_t *top = reinterpret_cast<uint8_t *>(mach_header.GetBase());
                uint8_t *blob = top + data;
                struct SuperBlob *super = reinterpret_cast<struct SuperBlob *>(blob);
                super->blob.magic = Swap(CSMAGIC_EMBEDDED_SIGNATURE);

                uint32_t count = xmld == NULL ? 2 : 3;
                uint32_t offset = sizeof(struct SuperBlob) + count * sizeof(struct BlobIndex);

                super->index[0].type = Swap(CSSLOT_CODEDIRECTORY);
                super->index[0].offset = Swap(offset);

                uint32_t begin = offset;
                struct CodeDirectory *directory = reinterpret_cast<struct CodeDirectory *>(blob + begin);
                offset += sizeof(struct CodeDirectory);

                directory->blob.magic = Swap(CSMAGIC_CODEDIRECTORY);
                directory->version = Swap(uint32_t(0x00020001));
                directory->flags = Swap(uint32_t(0));
                directory->codeLimit = Swap(data);
                directory->hashSize = 0x14;
                directory->hashType = 0x01;
                directory->spare1 = 0x00;
                directory->pageSize = 0x0c;
                directory->spare2 = Swap(uint32_t(0));

                directory->identOffset = Swap(offset - begin);
                strcpy(reinterpret_cast<char *>(blob + offset), name);
                offset += strlen(name) + 1;

                uint32_t special = xmld == NULL ? CSSLOT_REQUIREMENTS : CSSLOT_ENTITLEMENTS;
                directory->nSpecialSlots = Swap(special);

                uint8_t (*hashes)[20] = reinterpret_cast<uint8_t (*)[20]>(blob + offset);
                memset(hashes, 0, sizeof(*hashes) * special);

                offset += sizeof(*hashes) * special;
                hashes += special;

                uint32_t pages = (data + 0x1000 - 1) / 0x1000;
                directory->nCodeSlots = Swap(pages);

                if (pages != 1)
                    for (size_t i = 0; i != pages - 1; ++i)
                        sha1(hashes[i], top + 0x1000 * i, 0x1000);
                if (pages != 0)
                    sha1(hashes[pages - 1], top + 0x1000 * (pages - 1), ((data - 1) % 0x1000) + 1);

                directory->hashOffset = Swap(offset - begin);
                offset += sizeof(*hashes) * pages;
                directory->blob.length = Swap(offset - begin);

                super->index[1].type = Swap(CSSLOT_REQUIREMENTS);
                super->index[1].offset = Swap(offset);

                memcpy(blob + offset, "\xfa\xde\x0c\x01\x00\x00\x00\x0c\x00\x00\x00\x00", 0xc);
                offset += 0xc;

                if (xmld != NULL) {
                    super->index[2].type = Swap(CSSLOT_ENTITLEMENTS);
                    super->index[2].offset = Swap(offset);

                    uint32_t begin = offset;
                    struct Blob *entitlements = reinterpret_cast<struct Blob *>(blob + begin);
                    offset += sizeof(struct Blob);

                    memcpy(blob + offset, xmld, xmls);
                    offset += xmls;

                    entitlements->magic = Swap(CSMAGIC_ENTITLEMENTS);
                    entitlements->length = Swap(offset - begin);
                }

                for (size_t index(0); index != count; ++index) {
                    uint32_t type = Swap(super->index[index].type);
                    if (type != 0 && type <= special) {
                        uint32_t offset = Swap(super->index[index].offset);
                        struct Blob *local = (struct Blob *) (blob + offset);
                        sha1((uint8_t *) (hashes - type), (uint8_t *) local, Swap(local->length));
                    }
                }

                super->count = Swap(count);
                super->blob.length = Swap(offset);

                if (offset > size) {
                    fprintf(stderr, "offset (%u) > size (%u)\n", offset, size);
                    _assert(false);
                } //else fprintf(stderr, "offset (%zu) <= size (%zu)\n", offset, size);

                memset(blob + offset, 0, size - offset);
            }
        }

        if (flag_S) {
            uint8_t *top = reinterpret_cast<uint8_t *>(fat_header.GetBase());
            size_t size = fat_header.GetSize();

            char *copy;
            asprintf(&copy, "%s.%s.cp", dir, base);
            FILE *file = fopen(copy, "w+");
            size_t writ = fwrite(top, 1, size, file);
            _assert(writ == size);
            fclose(file);

            _syscall(unlink(temp));
            free(temp);
            temp = copy;
        }

        if (temp != NULL) {
            struct stat info;
            _syscall(stat(path, &info));
            _syscall(chown(temp, info.st_uid, info.st_gid));
            _syscall(chmod(temp, info.st_mode));
            _syscall(unlink(path));
            _syscall(rename(temp, path));
            free(temp);
        }

        free(dir);
        ++filei;
    } catch (const char *) {
        ++filee;
        ++filei;
    }

    return filee;
}
