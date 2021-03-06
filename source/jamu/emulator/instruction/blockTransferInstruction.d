module jamu.emulator.instruction.blockTransferInstruction;

import std.conv;
import std.bitmanip;
import std.format;
import std.stdio;

import jamu.emulator.machine;
import jamu.emulator.instruction;
import jamu.common.instructionStructs;

class BlockTransferInstruction : Instruction {

    uint[] getRegList() {
        uint[] r;
        foreach (i; 0..16) {
            if (castedBytes.regList & (1 << i))
                r ~= i;
        }
        return r;
    }

    this(uint location, ubyte[4] source) {
        super(location, source);
        assert(this.castedBytes.opcode == 0b100);
    }

    LoadStoreBlockInsn* castedBytes() {
        return cast(LoadStoreBlockInsn*) source.ptr;
    }

    override Machine* execute(Machine *m) {
        if (!conditionIsTrue(m)) {
            return super.execute(m);
        }

        // Get the target address
        auto targetAddress = m.getRegister(castedBytes.baseReg);
        auto offset = castedBytes.upBit
            ? getRegList().length * 4
            : -getRegList().length * 4;
        if (castedBytes.preBit)
            targetAddress += offset;


        if (castedBytes.loadBit) {
            auto mem = m.getMemory(
                    targetAddress,
                    cast(uint) getRegList().length*4);

            foreach(i, regNum; getRegList()) {
                uint value = * cast(uint*) mem[4*i..4*i+4].ptr;
                m.setRegister(regNum, value);
            }
        } else { // setBit
            foreach(i, regNum; getRegList()) {
                auto regVal = m.getRegister(regNum);
                ubyte[4] val = *cast(ubyte[4]*)&regVal;
                m.setMemory(targetAddress + 4*cast(uint)i,
                        val);
            }
        }

        if (!castedBytes.preBit)
            targetAddress += offset;

        if (castedBytes.writeBackBit)
            m.setRegister(castedBytes.baseReg, targetAddress);

        return super.execute(m);
    }

    override string toString() {
        auto ins = format!"%s%s R%d {"(
            castedBytes.loadBit ? "LDM" : "STM",
            castedBytes.writeBackBit ? "!" : "",
            castedBytes.baseReg);

        foreach(r; getRegList()) {
            ins ~= format!"R%d, "(r);
        }

        if (getRegList().length)
            ins = ins[0..$-2];

        ins ~= "}";

        return ins;
    }
}

