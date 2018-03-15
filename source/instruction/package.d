module instruction;

import std.conv;
import std.bitmanip;
import std.format;
import std.stdio;

import tokens;
import machine;

public import singleDataTransferInstruction;
public import branchInstruction;
public import dataProcessingInstruction;
public import blockTransferInstruction;

// Base class for a decompiled instruction that can be
// excecuted
class Instruction {
    uint location;
    ubyte[4] source;

    struct Insn {
        mixin(bitfields!(
            int,  "offset",     25,
            uint, "opcode",     3,
            uint, "cond",       4));
    }

    this(uint location, ubyte[4] source) {
        this.source = source;
        this.location = location;
    }

    bool conditionIsTrue(Machine* m) {
        auto cond = (cast(Insn *) source.ptr).cond;
        auto cpsr = m.getCpsr();

        switch (cond) {
            case 0b0000: return cpsr.zero;                      // EQ
            case 0b0001: return !cpsr.zero;                     // NE
            case 0b0010: return cpsr.carry;                     // CS
            case 0b0011: return !cpsr.carry;                    // CC
            case 0b0100: return cpsr.negative;                  // MI
            case 0b0101: return !cpsr.negative;                 // PL
            case 0b0110: return cpsr.overflow;                  // VS
            case 0b0111: return !cpsr.overflow;                 // VC
            case 0b1000: return cpsr.carry && !cpsr.zero;       // HI
            case 0b1001: return !cpsr.carry && cpsr.zero;       // LS
            case 0b1010: return cpsr.negative == cpsr.overflow; // GE
            case 0b1011: return cpsr.negative != cpsr.overflow; // LT
            case 0b1100: return !cpsr.zero                      // GT
                         && (cpsr.negative == cpsr.overflow);
            case 0b1101: return cpsr.zero                       // LE
                         || (cpsr.negative != cpsr.overflow);
            case 0b1110: return true;                           // AL
            default: assert(0); // Should throw invalid instruction
        }
    }

    string registerString(uint regNum) {
        assert(regNum <= 15);
        return "R" ~ to!string(regNum);
    }

    string conditionString() {
        auto cond = (cast(Insn *) source.ptr).cond;
        switch (cond) {
            case 0b0000: return "EQ";
            case 0b0001: return "NE";
            case 0b0010: return "CS";
            case 0b0011: return "CC";
            case 0b0100: return "MI";
            case 0b0101: return "PL";
            case 0b0110: return "VS";
            case 0b0111: return "VC";
            case 0b1000: return "HI";
            case 0b1001: return "LS";
            case 0b1010: return "GE";
            case 0b1011: return "LT";
            case 0b1100: return "GT";
            case 0b1101: return "LE";
            case 0b1110: return "";
            default: assert(0); // Should throw invalid instruction
        }
    }

    Machine* execute(Machine *m) {
        m.setRegister(15, m.pc() + 4);
        return m;
    }

    static Instruction parse(uint location, ubyte[] bytes) {
        assert(source.length == 4);
        auto faBytes = * cast(ubyte[4]*) bytes.ptr;
        auto uintBytes = * cast(uint*)faBytes.ptr;

        if (((uintBytes & 0xF0000000) >> 24) == 0xF) {
            return new UnimplementedInstruction(location, faBytes, "SWI");
        } else if ((uintBytes & 0x0C000000) == 0) {
            return new DataProcessingInstruction(location, faBytes);
        //} else if (((uintBytes & 0x0FC00000) >> 22) == 0) {
            //return new UnimplementedInstruction(location, faBytes, "MULT");
        //} else if (((uintBytes & 0x00000090) >> 4) == 9) {
            //return new UnimplementedInstruction(location, faBytes, "MULT2");
        } else if (((uintBytes & 0x0E000000) >> 25) == 5) {
            return new BranchInstruction(location, faBytes);
        } else if (((uintBytes & 0x0C000000) >> 26) == 1) {
            return new SingleTransferInstruction(location, faBytes);
        } else if (((uintBytes & 0x0E000000) >> 25) == 4) {
            return new BlockTransferInstruction(location, faBytes);
        } else {
            return new UnimplementedInstruction(location, faBytes, "BADINS");
        }
    }

    override string toString() {
        import std.digest;
        return "Unknown instruction: " ~
            to!string(toHexString!(LetterCase.lower)(source));
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
}

class UnimplementedInstruction : Instruction {
    string name;

    this(uint location, ubyte[4] source, string s) {
        super(location, source);
        this.name = s;
    }

    override string toString() {
        return name ~ " (UNIMP)";
    }
}

