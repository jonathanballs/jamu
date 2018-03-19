module jamu.tests.assembly;

import std.format;
import std.stdio;
import std.string;
import jamu.tests;
import jamu.assembler;
import jamu.emulator.instruction;

enum subTestsPerInstruction = 1024;
enum insWidth = 4;

class ASMTest : JamuTest {
    this() {
        this.testTarget = "disassembly";
    }

    void assertDisasm(string source) {
        ubyte[] b = Assembler.assembleString(source);
        auto disasm = Instruction.disasm(b);

        if (disasm != b) {
            auto sourceSplit = source.split('\n');
            auto disasmSplit = disasm.split('\n');

            foreach(i, line; sourceSplit) {
                if (disasmSplit[i] != line) {
                    assertEqual(line, disasmSplit[i]);
                    return;
                }
            }
        }
    }

    override void test() {
        testBranchInstruction();
        testLabels();
    }

    void testBranchInstruction() {
        subTestTarget = "branchInstruction";
        string source;
        foreach(i; 0..subTestsPerInstruction) {
            source ~= format!"B 0x%x\n"(i*insWidth);
        }
        assertDisasm(source);

        source = "";
        foreach(i; 0..subTestsPerInstruction) {
            source ~= format!"BL 0x%x\n"(i*insWidth);
        }
        assertDisasm(source);

    }

    void testLabels() {
        subTestTarget = "labels";
        string source = "testLabel:\n";
        string sourceNonLabel = "";
        foreach(i; 0..subTestsPerInstruction) {
            source ~= "B testLabel\n";
            sourceNonLabel ~= "B 0x0\n";
        }

        ubyte[] labelAsm = Assembler.assembleString(source);
        ubyte[] nlabelAsm = Assembler.assembleString(sourceNonLabel);

        assertEqual(labelAsm, nlabelAsm);
        assertDisasm(sourceNonLabel);
    }
}

