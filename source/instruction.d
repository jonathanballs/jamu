import std.conv;
import std.bitmanip;
import std.format;

import tokens;

// Base class for a decompiled instruction that can be
// excecuted
abstract class Instruction {
    uint location;
    ubyte[4] source;

    this(uint location, ubyte[4] source) {
        this.source = source;
        this.location = location;
    }

    void execute() {}

    static Instruction parse(uint location, ubyte[] bytes) {
        assert(source.length == 4);
        auto faBytes = * cast(ubyte[4]*) bytes.ptr;
        return new BranchInstruction(location, faBytes);
    }

    override string toString() {
        import std.digest;
        return "Unknown instruction: " ~
            to!string(toHexString!(LetterCase.lower)(source));
    }
}

class BranchInstruction : Instruction {
    struct BranchInsn {
        mixin(bitfields!(
            int, "offset",     24,
            bool, "linkbit",    1,
            uint, "opcode",     3,
            uint, "cond",       4));
    }

    this(uint location, ubyte[4] source) {
        super(location, source);
        assert(this.castedBytes.opcode == 0b101);
    }

    BranchInsn* castedBytes() {
        return cast(BranchInsn *) source.ptr;
    }

    override string toString() {
        auto mnemonic = "B" ~ (castedBytes.linkbit ? "L" : "");
        auto offset = castedBytes.offset << 2;
        return format!"%s 0x%x"(mnemonic, offset + location + 8);
    }
}

