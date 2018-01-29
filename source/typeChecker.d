import std.conv;
import std.stdio;

import tokens;
import ast;
import exceptions;

private struct InstructionTypes {
    OPCODES opcode;
    TypeInfo[] arguments;
}

// Look up type info from opcodes
private TypeInfo[][OPCODES] instructionTypes;

// Set opcode types
static this() {
    auto reg = typeid(Register);
    auto num = typeid(Integer);
    auto addr = typeid(Address);

    instructionTypes[OPCODES.adc] = [reg, reg, num];
    instructionTypes[OPCODES.add] = [reg, reg, num];
    instructionTypes[OPCODES.and] = [reg, reg, num];
    instructionTypes[OPCODES.b] = [addr];
    instructionTypes[OPCODES.bic] = [reg, reg, num];
    instructionTypes[OPCODES.bl] = [addr];
    instructionTypes[OPCODES.bx] = [];
    instructionTypes[OPCODES.cdp] = [];
    instructionTypes[OPCODES.cmn] = [reg, num];
    instructionTypes[OPCODES.cmp] = [reg, num];
    instructionTypes[OPCODES.eor] = [reg, reg, num];
    instructionTypes[OPCODES.ldc] = [];
    instructionTypes[OPCODES.ldm] = [];
    instructionTypes[OPCODES.ldr] = [reg, addr];
    instructionTypes[OPCODES.lsr] = [];
    instructionTypes[OPCODES.mcr] = [];
    instructionTypes[OPCODES.mla] = [reg, reg, reg, reg];
    instructionTypes[OPCODES.mov] = [reg, num];
    instructionTypes[OPCODES.mrc] = [];
    instructionTypes[OPCODES.mrs] = [];
    instructionTypes[OPCODES.mul] = [reg, reg, reg];
    instructionTypes[OPCODES.mvn] = [reg, num];
    instructionTypes[OPCODES.orr] = [];
    instructionTypes[OPCODES.rsb] = [reg, reg, num];
    instructionTypes[OPCODES.rsc] = [reg, reg, num];
    instructionTypes[OPCODES.sbc] = [reg, reg, num];
    instructionTypes[OPCODES.stc] = [];
    instructionTypes[OPCODES.stm] = [];
    instructionTypes[OPCODES.str] = [reg, addr];
    instructionTypes[OPCODES.sub] = [reg, reg, num];
    instructionTypes[OPCODES.swi] = [num];
    instructionTypes[OPCODES.swp] = [reg, reg, reg];
    instructionTypes[OPCODES.teq] = [reg, num];
    instructionTypes[OPCODES.tst] = [reg, num];

    instructionTypes[OPCODES.adr] = [reg, addr];
    instructionTypes[OPCODES.subs] = [reg, reg, addr];
}

class TypeChecker {
    Program program;

    TypeError[] errors;

    this (Program program_) {
        program = program_;
    }

    void checkInstructionTypes(Instruction instruction) {
        auto types = instructionTypes[instruction.opcode];
        if (instruction.arguments.length != types.length) {
            errors ~= new TypeError(instruction, "Error: "
                    ~ to!string(instruction.opcode) ~ " expects "
                    ~ to!string(types.length) ~ " but you provided "
                    ~ to!string(instruction.arguments.length));
            return;
        }
    }

    void checkDirectiveTypes(Directive directive) {
    }

    // Iterates over instructions and directives ensuring that they have the
    // correct arguments
    void checkTypes() {
        foreach(node; program.nodes) {
            if (node.type == typeid(Label)) {
                continue;
            } else if (node.type == typeid(Instruction)) {
                checkInstructionTypes(node.get!(Instruction));
                continue;
            } else if (node.type == typeid(Directive)) {
                checkDirectiveTypes(node.get!(Directive));
                continue;
            } else {
                assert(0);
            }
        }

        if (errors) {
            throw new TypeException(errors);
        }

        return;
    }

}

