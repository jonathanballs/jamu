module jamu.emulator.instruction.singleDataTransferInstruction;

import std.conv;
import std.bitmanip;
import std.format;
import std.stdio;

import jamu.emulator.machine;
import jamu.emulator.instruction;


class SingleTransferInstruction : Instruction {

    struct SingleTransferInsn {
        mixin(bitfields!(
            uint, "offset",     12,
            uint, "destReg",    4,
            uint, "baseReg",    4,
            bool, "loadBit",    1,
            bool, "writeBackBit",1,
            bool, "byteBit",    1,
            bool, "upBit",      1,
            bool, "preBit",     1,
            bool, "immediate",  1,
            byte, "opcode",     2,
            uint, "cond",       4));
    }

    SingleTransferInsn* castedBytes() {
        return cast(SingleTransferInsn*) source.ptr;
    }

    this(uint location, ubyte[4] source) {
        super(location, source);
    }

    override string toString() {
        auto raw = castedBytes();

        auto r = format!"%s%s%s R%d, "(
            raw.loadBit ? "LDR" : "STR",
            raw.byteBit ? "B" : "",
            conditionString(),
            raw.destReg);

        if (raw.immediate == 0) {
            r ~= format!"[R%d, #%s%d]%s"(
                raw.baseReg,
                raw.upBit ? "" : "-",
                raw.offset,
                raw.writeBackBit ? "!" : "");
        } else {
            auto offsetReg = raw.offset & 0xf;
            auto shift =    raw.offset >> 4;

            r ~= format!"[R%d, R%d%s]%s"(
                raw.baseReg,
                offsetReg,
                shift ? format!", #%s"(shift) : "",
                raw.writeBackBit ? "!" : "");}

        return r;
    }


    // TODO: Support half word and byte
    override Machine* execute(Machine *m) {
        if (!conditionIsTrue(m)) {
            return super.execute(m);
        }

        auto raw = castedBytes();

        uint loadAddress = m.getRegister(raw.baseReg);

        // Evaluate offset
        uint offset;
        if (raw.immediate) { // Offset is a register. Immediate is flipped for some reason
            offset = evaluateOp2(m, raw.offset, !raw.immediate);
        } else {
            offset = raw.offset;
        }
        offset = raw.upBit ? offset : -offset;

        if (raw.preBit) {
            loadAddress += offset;
        }

        // Make modifications
        if (raw.loadBit) { // Load val
            uint memVal = *cast(uint *)m.getMemory(loadAddress, 4).ptr;
            m.setRegister(raw.destReg, memVal);
        } else { // Store val
            uint regVal = m.getRegister(raw.destReg);
            ubyte[4] memVal = *cast(ubyte[4]*)&regVal;
            m.setMemory(loadAddress, memVal);
        }

        if (!raw.preBit) {
            loadAddress += offset;
        }

        if (raw.writeBackBit || !raw.preBit) {
            m.setRegister(raw.baseReg, loadAddress);
        }

        return super.execute(m);
    }

    unittest {
        auto ins = Instruction.parse(0, [0x04, 0xb0, 0x2d, 0xe5]);
        assert(ins.toString() == "STR R11, [R13, #-4]!");
    }
}

