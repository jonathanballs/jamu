import std.bitmanip;
import std.conv;
import std.stdio;
import std.variant;

import ast;
import exceptions;
import tokens;

struct BranchInsn {
    mixin(bitfields!(
        int, "offset",     24,
        bool, "linkbit",    1,
        uint, "opcode",     3,
        uint, "cond",       4));
}

struct InterruptInsn {
    mixin(bitfields!(
        uint, "comment",    24,
        uint, "opcode",     4,
        uint, "cond",       4));
}

struct DataProcessingInsn {
    mixin(bitfields!(
        uint, "operand2",   12,
        uint, "destReg",    4,
        uint, "operantReg", 4,
        bool, "setCodes",   1,
        uint, "opcode",     4,
        bool, "immediate",  1,
        uint, "",           2,
        uint, "cond",       4));
}

Token getToken(T)(T t) {
    return t.meta.tokens[0];
}

class CodeGenerator {

    Program program;
    TypeError[] errors;

    this (Program program_) {
        program = program_;
    }

    private bool ensureArgumentTypes(Instruction insn, TypeInfo[] types) {
        if (insn.arguments.length != types.length) {
            errors ~= new TypeError(getToken(insn), to!string(insn.opcode)
                    ~ " requires " ~ to!string(1) ~ " arguments");
            return false;
        }
        foreach(i, arg; insn.arguments) {
            if (arg.type != types[i]) {
                errors ~= new TypeError(getToken(insn), "Expected " ~ to!string(types[i])
                        ~ " but got " ~ to!string(arg.type));
                return false;
            }
        }
        return true;
    }


    ubyte[] generateBranchInstruction(Instruction insn) {
        assert(insn.opcode == OPCODES.b || insn.opcode == OPCODES.bl);

        if (!ensureArgumentTypes(insn, [typeid(Address)])) {
            return [0, 0, 0, 0];
        }

        BranchInsn* branchInsn = new BranchInsn;
        branchInsn.cond = cast(uint)insn.extension;
        branchInsn.opcode = 0b101;
        branchInsn.linkbit = insn.opcode == OPCODES.bl;

        // Offset is the signed 2's complement 24 bit offset shifted two
        // bits left. This is added to the program counter thus it must
        // take into account the prefetch which causes the PC to be 2 words
        // (8 bytes) ahead of 
        // TODO: Ensure that offset fits in the 24 bit space
        uint targetAddress = insn.arguments[0].get!Address.value;
        int offset = (targetAddress - insn.address);
        branchInsn.offset = ((offset - 8) >> 2);

        return cast(ubyte[]) branchInsn[0..1];
    }

    ubyte[] generateInterruptInstruction(Instruction insn) {
        assert(insn.opcode == OPCODES.swi);

        if (!ensureArgumentTypes(insn, [typeid(Integer)])) {
            return [0, 0, 0, 0];
        }

        InterruptInsn* swiInsn = new InterruptInsn;
        swiInsn.cond = cast(uint)insn.extension;
        swiInsn.opcode = 0b1111;
        swiInsn.comment = insn.arguments[0].get!Integer.value;

        return cast(ubyte[]) swiInsn[0..1];
    }

    ubyte[] generateDataProcessingInstruction(Instruction insn) {

        TypeInfo[] argTypes;
        if (insn.arguments.length == 3
                && insn.arguments[2].type == typeid(Register)) {
            argTypes = [typeid(Register), typeid(Register), typeid(Register)];
        } else {
            argTypes = [typeid(Register), typeid(Register), typeid(Integer)];
        }

        if (!ensureArgumentTypes(insn, argTypes)) {
            return [0, 0, 0, 0];
        }

        DataProcessingInsn* dataInsn = new DataProcessingInsn;
        dataInsn.cond = cast(uint)insn.extension;
        dataInsn.opcode = cast(uint)insn.opcode;

        return cast(ubyte[]) dataInsn[0..1];
    }

    ubyte[] generateInstruction(Instruction ins) {
        switch (ins.opcode) {
            case OPCODES.b:
            case OPCODES.bl:
                return generateBranchInstruction(ins);
            case OPCODES.swi:
                return generateInterruptInstruction(ins);
            case OPCODES.and:
            case OPCODES.eor:
            case OPCODES.sub:
            case OPCODES.rsb:
            case OPCODES.add:
            case OPCODES.adc:
            case OPCODES.sbc:
            case OPCODES.rsc:
            case OPCODES.orr:
            case OPCODES.bic:
                return generateDataProcessingInstruction(ins);
            case OPCODES.tst:
            case OPCODES.teq:
            case OPCODES.cmp:
            case OPCODES.cmn:
                // return unwritten data processing insn
            default:
                return [0, 0, 0, 0];
        }
    }

    ubyte[] generateDirective(Directive dir) {
        ubyte[] r;
        foreach(i; 0..dir.size) {
            r ~= 0;
        }

        return r;
    }

    // Convert AST to machine code
    ubyte[] generateCode() {

        ubyte[] code;

        foreach (node; program.nodes) {
            if (node.type == typeid(Instruction)) {
                assert(node.get!Instruction.address == code.length);
                code ~= generateInstruction(node.get!Instruction);
            } else if (node.type == typeid(Directive)) {
                assert(node.get!Directive.address == code.length);
                code ~= generateDirective(node.get!Directive);
            }
        }

        if (errors) {
            throw new TypeException(errors);
        }

        return code;
    }
}

