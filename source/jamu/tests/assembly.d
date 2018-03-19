module jamu.tests.assembly;

import std.format;
import std.stdio;
import jamu.tests;
import jamu.assembler;
import jamu.emulator.instruction;

enum subTestsPerInstruction = 16;
enum insWidth = 4;

class ASMTest : JamuTest {
    this() {
        this.testTarget = "disassembly";
    }

    override void test() {
        foreach(i; 0..subTestsPerInstruction) {
            string source = format!"B 0x%x"(i*insWidth);
            ubyte[] b = Assembler.assembleString(source);
            assertEqual(source, Instruction.parse(0, b).toString());
        }
    }
}

