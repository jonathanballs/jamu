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

        switch ((cast(Insn *) faBytes.ptr).opcode) {
            case 0b101:
                return new BranchInstruction(location, faBytes);
            case 0b001:
            case 0b000:
                return new DataProcessingInstruction(location, faBytes);
            case 0b010:
            case 0b011:
                return new SingleTransferInstruction(location, faBytes);
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

