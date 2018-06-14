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
import jamu.assembler.lexer;
import jamu.assembler.parser;
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

        // Test internals
        testIntegerParsing();
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


    //
    // Test assembler internals
    //
    void testIntegerParsing() {
        auto testNums = [
            "1"     : 1, // Standard decimal
            "79"    : 79,
            "2001"  : 2001,
            "#1"    : 1,
            "#79"   : 79,
            "#2001" : 2001,

            "0x1"   : 0x1, // Hexidecimal
            "0x79"  : 0x79,
            "0x2001": 0x2001,
            "#0x1"  : 0x1,
            "#0x79" : 0x79,
            "#0x2a01":0x2a01,

            "0b1"   : 0b1, // Binary
            "0b1001": 0b1001,
            "#0b1"  : 0b1,
            "#0b1001":0b1001,
        ];

        foreach(testNum; testNums.byKey) {
            auto t = new Lexer("", testNum).lexInteger();
            auto p = new Parser([t]);
            assertEqual(testNums[testNum], p.parseInteger().value);
        }
    }

}

