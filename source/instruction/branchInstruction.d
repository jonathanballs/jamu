import std.conv;
import std.bitmanip;
import std.format;
import std.stdio;

import machine;
import instruction;

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

    override Machine* execute(Machine *m) {
        if (conditionIsTrue(m)) {
            m.setRegister(15, m.pc() + (castedBytes.offset << 2) + 8);
            return m;
        } else {
            return super.execute(m);
        }
    }

    override string toString() {
        auto mnemonic = "B" ~ (castedBytes.linkbit ? "L" : "");
        auto offset = castedBytes.offset << 2;
        return format!"%s%s 0x%x"(mnemonic,
               conditionString(),
               offset + location + 8);
    }
}
