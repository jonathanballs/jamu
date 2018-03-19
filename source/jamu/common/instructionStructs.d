module jamu.common.instructionStructs;

import std.bitmanip;

struct BranchInsn {
    mixin(bitfields!(
        int, "offset",     24,
        bool, "linkbit",    1,
        uint, "opcode",     3,
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

struct LoadStoreInsn {
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

struct LoadStoreBlockInsn {
    mixin(bitfields!(
        int,  "regList",    16,
        uint, "baseReg",    4,
        bool, "loadBit",    1,
        bool, "writeBackBit",1,
        bool, "PSRBit",     1,
        bool, "upBit",      1,
        bool, "preBit",     1,
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

