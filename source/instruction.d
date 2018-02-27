import std.conv;
import std.bitmanip;
import std.format;

import tokens;
import machine;

// Base class for a decompiled instruction that can be
// excecuted
class Instruction {
    uint location;
    ubyte[4] source;

    this(uint location, ubyte[4] source) {
        this.source = source;
        this.location = location;
    }

    Machine* execute(Machine *m) {
        m.setRegister(15, m.pc() + 4);
        return m;
    }

    static Instruction parse(uint location, ubyte[] bytes) {
        assert(source.length == 4);
        auto faBytes = * cast(ubyte[4]*) bytes.ptr;

        // First we must detect what kind of instruction it is
        struct Insn {
            mixin(bitfields!(
                int,  "offset",     25,
                uint, "opcode",     3,
                uint, "cond",       4));
        }

        switch ((cast(Insn *) faBytes.ptr).opcode) {
            case 0b101:
                return new BranchInstruction(location, faBytes);
            default:
                return new Instruction(location, faBytes);
        }
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

