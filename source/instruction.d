import std.conv;
import std.bitmanip;
import std.format;
import std.stdio;

import tokens;
import machine;

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

    string conditionString(uint cond) {
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
               conditionString(castedBytes.cond),
               offset + location + 8);
    }
}

class DataProcessingInstruction : Instruction {

    override Machine* execute(Machine *m) {

        if (!conditionIsTrue(m)) {
            writeln("Condition is false.. skipping");
            return super.execute(m);
        }

        auto op2Val = castedBytes.immediate
            ? castedBytes.operand2
            : m.getRegister(castedBytes.operand2);
        auto op1Val = m.getRegister(castedBytes.operandReg);

        auto cpsr = m.getCpsr();

        uint result;
        switch(instructionString()) {
            case "AND": result = op1Val & op2Val; break;
            case "EOR": result = op1Val ^ op2Val; break;
            case "SUB": result = op1Val - op2Val; break;
            case "RSB": result = op2Val - op1Val; break;
            case "ADD": result = op1Val + op2Val; break;
            case "ADC": result = op1Val + op2Val + cpsr.carry; break;
            case "SBC": result = op1Val - op2Val - 1 + cpsr.carry; break;
            case "RSC": result = op2Val - op1Val - 1 + cpsr.carry; break;
            case "TST": result = op1Val & op2Val; break;
            case "TEQ": goto case "EOR";
            case "CMP": goto case "SUB";
            case "CMN": goto case "ADD";
            case "ORR": result = op1Val | op2Val; break;
            case "MOV": result = op2Val; break;
            case "BIC": result = op1Val & ~op2Val; break;
            case "MVN": result = 0xFFFFFFFF ^ op2Val; break;
            default:
                import std.stdio;
                writeln("ERR: NOT IMPLEMENTED");
                break;
        }

        if (isWriteInstruction()) {
            m.setRegister(castedBytes.destReg, result);
        }

        if (isSaveInstruction()) {
            cpsr.zero = result == 0;
            m.setCpsr(cpsr);
        }

        return super.execute(m);
    }

    struct DataProcessingInsn {
        mixin(bitfields!(
            uint, "operand2",    12,
            uint, "destReg",    4,
            uint, "operandReg", 4,
            bool, "setBit",     1,
            uint, "opcode",     4,
            bool, "immediate",  1,
            uint, "",           2,
            uint, "cond",       4));
    }

    string instructionString() {
        switch (castedBytes.opcode) {
            case 0b0000: return "AND";
            case 0b0001: return "EOR";
            case 0b0010: return "SUB";
            case 0b0011: return "RSB";
            case 0b0100: return "ADD";
            case 0b0101: return "ADC";
            case 0b0110: return "SBC";
            case 0b0111: return "RSC";
            case 0b1000: return "TST";
            case 0b1001: return "TEQ";
            case 0b1010: return "CMP";
            case 0b1011: return "CMN";
            case 0b1100: return "ORR";
            case 0b1101: return "MOV";
            case 0b1110: return "BIC";
            case 0b1111: return "MVN";
            default: assert(0); // Should throw invalid instruction
        }
    }

    bool isWriteInstruction() {
        switch (instructionString()) {
            case "TST":
            case "TEQ":
            case "CMP":
            case "CMN":
                return false;
            default:
                return true;
        }
    }


    bool isSaveInstruction() {
        switch (instructionString()) {
            case "TST":
            case "TEQ":
            case "CMP":
            case "CMN":
                return true;
            default:
                return castedBytes.setBit;
        }
    }

    DataProcessingInsn* castedBytes() {
        return cast(DataProcessingInsn *) source.ptr;
    }

    this(uint location, ubyte[4] source) {
        super(location, source);
    }

    override string toString() {
        auto ins = instructionString() ~ conditionString(castedBytes.cond)
            ~ " " ~ registerString(castedBytes.destReg) // Destination reg
            ~ ", " ~ registerString(castedBytes.operandReg);
        if (castedBytes.immediate) {
            ins ~= ", #" ~ to!string(castedBytes.operand2);
        } else {
            ins ~= ", " ~ registerString(castedBytes.operand2);
        }

        return ins;
    }
}

