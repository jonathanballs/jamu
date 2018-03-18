import std.algorithm : canFind;
import std.bitmanip;
import std.conv;
import std.stdio;
import std.variant;
import std.math : abs;

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

struct BranchExchangeInsn {
    mixin(bitfields!(
        uint,  "operandReg", 4,
        uint, "opcode",     24,
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
        uint, "operand2",    12,
        uint, "destReg",    4,
        uint, "operandReg", 4,
        bool, "setBit",     1,
        uint, "opcode",     4,
        bool, "immediate",  1,
        uint, "",           2,
        uint, "cond",       4));
}

struct LoadInsn {
    mixin(bitfields!(
        uint, "offset",     12,
        uint, "destReg",    4,
        uint, "operandReg", 4,
        bool, "loadBit",    1,
        bool, "writeBackBit",1,
        bool, "byteBit",    1,
        bool, "upBit",      1,
        bool, "preBit",     1,
        bool, "immediate",  1,
        byte, "opcode",     2,
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
            if (arg.type == typeid(Address) && types[i] == typeid(Integer)) {
                dir.arguments[i] = Integer(arg.get!Address.value, arg.get!Address.meta);
                arg = dir.arguments[i];
            } else if (arg.type == typeid(Integer) && types[i] == typeid(Address)) {
                dir.arguments[i] = Address(arg.get!Integer.value, arg.get!Integer.meta);
                arg = dir.arguments[i];
            }
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
                    ~ " requires " ~ to!string(types.length) ~ " arguments");
            return false;
        }
        foreach(i, arg; insn.arguments) {
            // Convert between address and integers
            if (arg.type == typeid(Address) && types[i] == typeid(Integer)) {
                insn.arguments[i] = Integer(arg.get!Address.value, arg.get!Address.meta);
                arg = insn.arguments[i];
            } else if (arg.type == typeid(Integer) && types[i] == typeid(Address)) {
                insn.arguments[i] = Address(arg.get!Integer.value, arg.get!Integer.meta);
                arg = insn.arguments[i];
            }

            if (arg.type != types[i]) {
                errors ~= new TypeError(getToken(insn), "Expected " ~ to!string(types[i])
                        ~ " but got " ~ to!string(arg.type));
                return false;
            }
        }
        types = [];
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

    ubyte[] generateBranchExchangeInstruction(Instruction insn) {
        if (!ensureArgumentTypes(insn, [typeid(Register)])) {
            return [0, 0, 0, 0];
        }

        assert(insn.opcode == OPCODES.bx);
        BranchExchangeInsn* branchInsn = new BranchExchangeInsn;
        branchInsn.cond = cast(uint)insn.extension;
        branchInsn.opcode = 0b00100101111111111110001;
        branchInsn.operandReg = to!uint(insn.arguments[0].get!Register.register);

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
        assert(dataProcessingOpcodes.canFind(insn.opcode));

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
            case OPCODES.tst: opcode = 0b1000; break;
            case OPCODES.teq: opcode = 0b1001; break;
            case OPCODES.cmp: opcode = 0b1010; break;
            case OPCODES.cmn: opcode = 0b1011; break;
            case OPCODES.orr: opcode = 0b1100; break;
            case OPCODES.mov: opcode = 0b1101; break;
            case OPCODES.bic: opcode = 0b1110; break;
            case OPCODES.mvn: opcode = 0b1111; break;
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

    // These instructions data processing instructions but the result is not
    // written. They simply modify to the CSPR. We do type checking and then
    // modify the args to conform to normal data processing ins and then pass
    // it to generateDataProcessingInstruction()
    ubyte[] generateCompDataProcessingInstruction(Instruction insn) {
        TypeInfo[] argTypes;
        if (insn.arguments.length == 2
                && insn.arguments[1].type == typeid(Register)) {
            argTypes = [typeid(Register), typeid(Register)];
        } else {
            argTypes = [typeid(Register), typeid(Integer)];
        }

        if (!ensureArgumentTypes(insn, argTypes)) {
            return [0, 0, 0, 0];
        }

        Variant regV = cast(Variant)Register(REGISTERS.r0);
        insn.arguments = [regV] ~ insn.arguments;
        insn.setBit = true;

        return generateDataProcessingInstruction(insn);
    }

    ubyte[] generateMovInstruction(Instruction insn) {
        assert(insn.opcode == OPCODES.mov
                || insn.opcode == OPCODES.mvn);

        TypeInfo[] argTypes;
        if (insn.arguments.length == 2
                && insn.arguments[1].type == typeid(Register)) {
            argTypes = [typeid(Register), typeid(Register)];
        } else {
            argTypes = [typeid(Register), typeid(Integer)];
        }

        if (!ensureArgumentTypes(insn, argTypes)) {
            return [0, 0, 0, 0];
        }

        Variant regV = cast(Variant)Register(REGISTERS.r0);
        insn.arguments = [insn.arguments[0], regV, insn.arguments[1]];
        return generateDataProcessingInstruction(insn);
    }

    // The ADR pseudo instruction gets compiled down to a sub or add instruction
    // relative to the program counter.
    ubyte[] generateAdrInstruction(Instruction insn) {
        assert(insn.opcode == OPCODES.adr);

        if (!ensureArgumentTypes(insn, [typeid(Register), typeid(Address)]))
            return [0, 0, 0, 0];

        // Set the opcode
        int offset = insn.arguments[1].get!Address.value - (insn.address + 8);
        insn.opcode = (offset < 0) ? OPCODES.sub : OPCODES.add;

        // Get offset from address
        auto offsetArg = cast(Variant)Integer(abs(offset),
                insn.arguments[1].get!Address.meta);

        // Insert PC into argument list
        Variant regV = cast(Variant)Register(REGISTERS.r15);
        insn.arguments = [insn.arguments[0], regV, offsetArg];

        return generateDataProcessingInstruction(insn);
    }

    ubyte[] generateLoadInstruction(Instruction insn) {

        if (!ensureArgumentTypes(insn,
                    [typeid(Register), typeid(Address)])) {
            return [0,0,0,0];
        }

        LoadInsn* loadInsn = new LoadInsn;
        loadInsn.cond = cast(uint)insn.extension;
        loadInsn.opcode = 0b01;
        loadInsn.destReg = to!uint(insn.arguments[0].get!Register.register);

        int offset = insn.arguments[1].get!Address.value - (insn.address + 8);
        loadInsn.upBit = offset >= 0;
        loadInsn.offset = abs(offset);
        loadInsn.operandReg = 0b1111;
        loadInsn.preBit = true;
        loadInsn.loadBit = insn.opcode == OPCODES.ldr;

        return cast(ubyte[]) loadInsn[0..1];
    }

    ubyte[] generateInstruction(Instruction ins) {
        switch (ins.opcode) {
            case OPCODES.b:
            case OPCODES.bl:
                return generateBranchInstruction(ins);
            case OPCODES.bx:
                return generateBranchExchangeInstruction(ins);
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
                return generateCompDataProcessingInstruction(ins);
            case OPCODES.adr:
                return generateAdrInstruction(ins);
            case OPCODES.mov:
            case OPCODES.mvn:
                return generateMovInstruction(ins);
            case OPCODES.ldr:
            case OPCODES.str:
                return generateLoadInstruction(ins);
            default:
                return [0, 0, 0, 0];
        }
    }

    ubyte[] generateDirective(Directive dir) {
        ubyte[] r;
        if (dir.directive == DIRECTIVES.align_) {
            ensureArgumentTypes(dir, []);
            assert(dir.size < 4);
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
                    // TODO: Generate type error and create array of correct
                    // number of bytes
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

