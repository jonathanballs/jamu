module jamu.emulator.instruction.softwareInterruptInstruction;

import std.ascii;
import std.conv;
import std.format;
import std.stdio;

import jamu.emulator.machine;
import jamu.emulator.instruction;
import jamu.common.instructionStructs;

class SoftwareInterruptInstruction : Instruction {

    this(uint location, ubyte[4] source) {
        super(location, source);
        assert(this.castedBytes.opcode == 0b1111);
    }

    InterruptInsn* castedBytes() {
        return cast(InterruptInsn *) source.ptr;
    }

    override Machine* execute(Machine *m) {
        auto swiNum = castedBytes.comment;
        if (swiNum == 0) {
            m.appendOutput("" ~ to!char(m.getRegisters()[0] & 0xFF));
        } else if (swiNum == 3) {
            string outputString;

            uint charAddress = m.getRegisters()[0];
            foreach(i; 0..256) { // Limit string length
                char charVal = to!char(m.getMemory(charAddress + i, 1)[0]);

                if (charVal == 0) {
                    break;
                } else {
                    outputString ~= charVal;
                }

                charVal++;
            }

            m.appendOutput(outputString);
        } else if (swiNum == 4) {
            m.appendOutput(format!"%d"(m.getRegisters()[0]));
        }

        return super.execute(m);
    }

    override string toString() {
        return format!"SWI %d"(castedBytes.comment);
    }
}

