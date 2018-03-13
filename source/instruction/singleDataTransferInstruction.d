import instruction;
import std.conv;
import std.bitmanip;
import std.format;
import std.stdio;

import machine;

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

    uint evaluateOp2(Machine* m, uint operand, bool immediate) {
        import core.bitop;

        if (immediate) {
            // 11      8 7                 0|
            // | Rotate |     Immediate     |
            // ------------------------------
            // The immediate value is rotated right by Rotate*2
            uint value = operand & 0xff;
            uint rotate = operand >> 8;

            return ror(value, rotate*2);
        } else { // Shifting a register

            //  -----------------------------
            // |11               4|3       0|
            //  -----------------------------
            // |       Shift      |   Reg   |
            //  ----------------------------

            // Where shift is either:
            //  -----------------------------
            // |11           7|6        5| 4 |
            //  -----------------------------
            // |   Amount     |   Type   | 1 |
            //  -----------------------------

            // Or:
            //  -----------------------------
            // |11       8| 7 |6        5| 5 |
            //  -----------------------------
            // |   Reg    | 0 |   Type   | 0 |
            //  -----------------------------

            uint valToShift = m.getRegister(operand & 0xf);
            uint shift = operand >> 4;

            uint shiftAmount;
            uint shiftType = (shift >> 1) & 0x3;

            if (shift & 1) { // If shifting by hardcoded amount
                shiftAmount = shift >> 3;
            } else {
                shiftAmount = m.getRegister(shift >> 4);
            }


            switch (shiftType) {
                case 0b00: return valToShift << shiftAmount; // LSL
                case 0b01: return valToShift >>> shiftAmount; // LSR
                case 0b10: return valToShift >> shiftAmount; // ARR
                case 0b11: return ror(valToShift, shiftAmount); // ROR
                default: assert(0);
            }
        }
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
            writeln("memVal: ", memVal);
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

