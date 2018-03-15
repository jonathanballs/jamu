import std.conv;
import std.bitmanip;
import std.format;
import std.stdio;

import machine;
import instruction;

class BlockTransferInstruction : Instruction {
    struct BlockTransferInsn {
        mixin(bitfields!(
            int,  "regList",    16,
            uint, "baseReg",    4,
            bool, "loadBit",    1,
            bool, "writeBackBit",1,
            bool, "PSRBit",     1,
            bool, "upBit",      1,
            bool, "preBit",     1,
            uint, "opcode",     3,
            uint, "cond",       4));
    }

    uint[] getRegList() {
        uint[] r;
        foreach (i; 0..16) {
            if (castedBytes.regList & (1 << i))
                r ~= i;
        }
        return r;
    }

    this(uint location, ubyte[4] source) {
        super(location, source);
        assert(this.castedBytes.opcode == 0b100);
    }

    BlockTransferInsn* castedBytes() {
        return cast(BlockTransferInsn*) source.ptr;
    }

    override Machine* execute(Machine *m) {
        if (!conditionIsTrue(m)) {
            return super.execute(m);
        }

        return super.execute(m);
    }

    override string toString() {
        auto ins = castedBytes.loadBit ? "LDM " : "STM ";
        foreach(r; getRegList()) {
            ins ~= format!"R%d, "(r);
        }

        return ins;
    }
}

