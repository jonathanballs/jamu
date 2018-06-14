module jamu.tests.assembly;
// Tests assembly from the test suite

import std.file;
import std.format;
import std.stdio;
import std.string;
import std.digest;
import std.json;

import jamu.tests;
import jamu.assembler;
import jamu.emulator.instruction;

enum subTestsPerInstruction = 1024;
enum insWidth = 4;
enum testSuiteFilename = "./test/test_suite.json";

class ASMTest : JamuTest {

    Assembler assembler;
    JSONValue testSuite;

    this() {
        this.testTarget = "assembly";
    }

    override void test() {
        testSuite = parseJSON(readText(testSuiteFilename));

        // run the test suite
        foreach(testGroup; testSuite.array) {
            foreach(testCase; testGroup["test_cases"].object.byKey) {
                testAssembly(testCase, testGroup["test_cases"][testCase].str);
            }
        }
    }

    void testAssembly(string assembly, string hex) {
        string h;
        try {
            h = toHexString!(LetterCase.lower)(assembler.assembleString(assembly));
        } catch (Exception e) {
            writeln("\nFailed to compile: ", assembly);
            throw e;
        }

        auto errMessage = assembly ~ "\t-> " ~ h ~ ". Should be " ~ hex;

        assertEqual(h, hex.toLower(), errMessage);
    }
}

