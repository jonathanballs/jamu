import std.stdio;
// A class for generating elf files

struct ElfIdent {
    char[4] e_magic         = "\x7fELF";
    byte e_class            = 0x1;  // 32bit binary
    byte e_data             = 0x1;  // Little endian
    byte e_version          = 0x1;  // ELF format version
    byte[9] e_pad           = [0,0,0,0,0,0,0,0,0];
}

struct ElfHeader {
    ElfIdent ident;
    ushort e_type           = 0x2;  // Executable file
    ushort e_machine        = 40; // ARM
    uint e_version          = 0x1;  // Version 1
    uint e_entry            = 0x0;  // Enter at 0x0
    uint e_phoff            = ElfHeader.sizeof;
    uint e_shoff;
    uint e_flags;
    ushort e_ehsize         = ElfHeader.sizeof;
    ushort e_phentsize      = ProgramHeader.sizeof;
    ushort e_phnum          = 1;
    ushort e_shentsize      = SectionHeader.sizeof;
    ushort e_shnum          = 0;
    ushort e_shstrndx;
}

struct ProgramHeader {
    uint p_type             = 0x1; // PT_LOAD
    uint p_offset           = ElfHeader.sizeof + ProgramHeader.sizeof;
    uint p_vaddr            = 0x0;
    uint p_paddr            = 0x0;
    uint p_filesz;
    uint p_memsz;
    uint p_flags            = 0x0;
    uint p_align            = 0x4;
}

struct SectionHeader {
    uint sh_name;
    uint sh_type;
    uint sh_flags;
    uint sh_addr;
    uint sh_offset;
    uint sh_size;
    uint sh_link;
    uint sh_info;
    uint sh_addralign;
    uint sh_entsize;
}

// Assert sizes
static assert(ElfIdent.sizeof == 0x10);
static assert(ElfHeader.sizeof == 0x34);
static assert(ProgramHeader.sizeof == 0x20);
static assert(SectionHeader.sizeof == 0x28);

class ElfGenerator {
    ubyte[] program;

    this(ubyte[] program_) {
        program = program_;
    }

    void writeElfFile(string filename) {
        auto elfHeader = new ElfHeader;
        auto pHeader = new ProgramHeader;

        pHeader.p_filesz = cast(uint) program.length;
        pHeader.p_memsz = cast(uint) program.length;

        auto file = new File(filename, "w+");

        fwrite(elfHeader, byte.sizeof, ElfHeader.sizeof, file.getFP());
        fwrite(pHeader, byte.sizeof, ProgramHeader.sizeof, file.getFP());
        fwrite(program.ptr, byte.sizeof, program.length, file.getFP());
        //file.write(program.ptr);

        file.close();
    }
}

