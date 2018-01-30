import std.stdio;
import std.conv;
import std.bitmanip;
import ast;
import tokens;
import exceptions;

struct BranchInsn {
    mixin(bitfields!(
        int, "offset",     24,
        bool, "linkbit",    1,
        uint, "opcode",     3,
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

    ubyte[] generateBranchInstruction(Instruction insn) {
        assert(insn.opcode == OPCODES.b || insn.opcode == OPCODES.bl);

        // Check argument types
        if (insn.arguments.length != 1) {
            errors ~= new TypeError(getToken(insn), "Requires 1 argument");
            return [0, 0, 0, 0];
        }

        if (insn.arguments[0].type != typeid(Address)) {
            errors ~= new TypeError(getToken(insn), "Requires argument to be an address");
            return [0, 0, 0, 0];
        }

        BranchInsn *branchInsn = new BranchInsn;
        branchInsn.cond = cast(uint)insn.extension;
        branchInsn.opcode = 0b101;
        branchInsn.linkbit = insn.opcode == OPCODES.bl;

        // Offset is the signed 2's complement 24 bit offset shifted two
        // bits left. This is added to the program counter thus it must
        // take into account the prefetch which causes the PC to be 2 words
        // (8 bytes) ahead of 
        uint targetAddress = insn.arguments[0].get!Address.value;
        int offset = (targetAddress - insn.address);
        branchInsn.offset = ((offset - 8) >> 2);

        return cast(ubyte[]) branchInsn[0..1];
    }

    ubyte[] generateInstruction(Instruction ins) {
        switch (ins.opcode) {
            case OPCODES.b:
            case OPCODES.bl:
                return generateBranchInstruction(ins);
            default:
                ubyte[] compInsn = [0, 0, 0, 0];
                return compInsn;
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
                code ~= generateDirective(node.get!Directive);
            }
        }

        return code;
    }
}

