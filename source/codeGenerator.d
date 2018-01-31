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
        uint, "operandReg", 4,
        bool, "setBit",     1,
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

    private bool ensureArgumentTypes(Directive dir, TypeInfo[] types) {
        if (dir.arguments.length != types.length) {
            errors ~= new TypeError(getToken(dir), to!string(dir.directive)
                    ~ " requires " ~ to!string(dir.arguments.length) ~ " arguments");
            return false;
        }
        foreach(i, arg; dir.arguments) {
            if (arg.type != types[i]) {
                errors ~= new TypeError(getToken(dir), "Expected " ~ to!string(types[i])
                        ~ " but got " ~ to!string(arg.type));
                return false;
            }
        }
        return true;
    }

    private bool ensureArgumentTypes(Instruction insn, TypeInfo[] types) {
        if (insn.arguments.length != types.length) {
            errors ~= new TypeError(getToken(insn), to!string(insn.opcode)
                    ~ " requires " ~ to!string(insn.arguments.length) ~ " arguments");
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

        uint opcode;
        switch(insn.opcode) {
            case OPCODES.and: opcode = 0b0000; break;
            case OPCODES.eor: opcode = 0b0001; break;
            case OPCODES.sub: opcode = 0b0010; break;
            case OPCODES.rsb: opcode = 0b0011; break;
            case OPCODES.add: opcode = 0b0100; break;
            case OPCODES.adc: opcode = 0b0101; break;
            case OPCODES.sbc: opcode = 0b0110; break;
            case OPCODES.rsc: opcode = 0b0111; break;
            //case OPCODES.tst: opcode = 0b1000; break;
            //case OPCODES.teq: opcode = 0b1001; break;
            //case OPCODES.cmp: opcode = 0b1010; break;
            //case OPCODES.cmn: opcode = 0b1011; break;
            case OPCODES.orr: opcode = 0b1100; break;
            case OPCODES.bic: opcode = 0b1110; break;
            default: assert(0);
        }

        if (!ensureArgumentTypes(insn, argTypes)) {
            return [0, 0, 0, 0];
        }

        DataProcessingInsn* dataInsn = new DataProcessingInsn;
        dataInsn.cond = cast(uint)insn.extension;
        dataInsn.opcode = opcode;
        dataInsn.setBit = insn.setBit;
        dataInsn.destReg = to!uint(insn.arguments[0].get!Register.register);
        dataInsn.operandReg = to!uint(insn.arguments[1].get!Register.register);

        auto op2 = insn.arguments[2];
        if (op2.type == typeid(Integer)) {
            dataInsn.immediate = true;
            dataInsn.operand2 = op2.get!Integer.value;
        } else if (op2.type == typeid(Register)) {
            dataInsn.immediate = false;
            dataInsn.operand2 = to!int(op2.get!Register.register);
        } else {
            assert(0);
        }

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
            //case OPCODES.tst:
            //case OPCODES.teq:
            //case OPCODES.cmp:
            //case OPCODES.cmn:
            case OPCODES.orr:
            case OPCODES.bic:
                return generateDataProcessingInstruction(ins);
                // return unwritten data processing insn
            default:
                return [0, 0, 0, 0];
        }
    }

    ubyte[] generateDirective(Directive dir) {
        ubyte[] r;
        if (dir.directive == DIRECTIVES.align_) {
            ensureArgumentTypes(dir, []);
            foreach(i; 0..dir.size) {
                r ~= 0;
            }
        } else if (dir.directive == DIRECTIVES.defw) {
            auto arg = dir.arguments[0];
            if (arg.type == typeid(Integer)) {
                r ~= (cast(ubyte *)&arg.get!Integer.value)[0..uint.sizeof];
            }
        } else if (dir.directive == DIRECTIVES.defb) {
            foreach(arg; dir.arguments) {
                if (arg.type == typeid(Integer)) {
                    auto argI = arg.get!Integer;
                    r ~= cast(ubyte)argI.value;
                } else if (arg.type == typeid(String)) {
                    char[] s = arg.get!String.value.dup;
                    r ~= cast(ubyte[])s;
                } else {
                    assert(0);
                }
            }
        } else {
            assert(0);
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

