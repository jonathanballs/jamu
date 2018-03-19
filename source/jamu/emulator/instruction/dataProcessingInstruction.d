module jamu.emulator.instruction.dataProcessingInstruction;

import std.conv;
import std.bitmanip;
import std.format;
import std.stdio;

import jamu.emulator.machine;
import jamu.emulator.instruction;
import jamu.common.instructionStructs;

class DataProcessingInstruction : Instruction {

    override Machine* execute(Machine *m) {

        if (!conditionIsTrue(m)) {
            return super.execute(m);
        }

        auto op2Val = evaluateOp2(m, castedBytes.operand2, castedBytes.immediate);
        auto op1Val = m.getRegister(castedBytes.operandReg);

        auto cpsr = m.getCpsr();

        uint result;
        switch(instructionString()) {
            case "AND": result = op1Val & op2Val; break;
            case "EOR": result = op1Val ^ op2Val; break;
            case "SUB":
                result = op1Val - op2Val;
                cpsr.overflow = op1Val < op2Val;
                break;
            case "RSB": result = op2Val - op1Val; break;
            case "ADD":
                result = op1Val + op2Val;
                cpsr.overflow = (0xffffffff - op1Val) > op2Val;
                break;
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

        if (modifiesCPSR()) {
            cpsr.zero = result == 0;
            m.setCpsr(cpsr);
        }

        return super.execute(m);
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


    // Does it modify CSPR
    bool modifiesCPSR() {
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

    bool usesBaseRegister() {
        switch (instructionString()) {
            case "MOV":
                return false;
            default:
                return true;
        }
    }

    bool usesDestReg() {
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

    DataProcessingInsn* castedBytes() {
        return cast(DataProcessingInsn *) source.ptr;
    }

    this(uint location, ubyte[4] source) {
        super(location, source);
    }

    override string toString() {
        auto ins = instructionString() ~ conditionString();

        if (usesDestReg()) {
            ins ~= " " ~ registerString(castedBytes.destReg); // Destination reg
        }

        if (usesBaseRegister()) {
            if (usesDestReg())
                ins ~= ",";

            ins ~= " " ~ registerString(castedBytes.operandReg);
        }

        if (castedBytes.immediate) {
            ins ~= ", #" ~ to!string(castedBytes.operand2);
        } else {
            ins ~= ", " ~ registerString(castedBytes.operand2 & 0xf);
        }

        return ins;
    }
}

