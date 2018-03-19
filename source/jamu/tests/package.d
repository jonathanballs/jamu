module jamu.tests;

import std.stdio;
import std.conv;
import colorize : fg, color, cwrite, cwriteln, cwritefln;

import jamu.tests.assembly;

class JamuTestRunner {
    void run() {
        // List of all tests to run
        JamuTest[] tests = [
            new TestTests(),
            new ASMTest()
        ];

        foreach(test; tests) {
            test.run();
        }
    }
}

abstract class JamuTest {
    string testTarget = "Unknown";
    string subTestTarget;
    uint totalAssertions = 0;
    string[] errorMessages;

    final void run() {
        write("Testing ", testTarget, "...");
        stdout.flush;

        this.test();

        if (this.errorMessages) {
            cwriteln(" 🗴".color(fg.light_red));
            foreach(message; errorMessages) {
                if (subTestTarget.length)
                    cwrite("    ", subTestTarget.color(fg.blue), ":");
                else
                    write("    ");
                writeln(message);
            }
        } else {
            cwriteln(" ✔".color(fg.light_green));
        }
    }

    void test() {}
    // Assertions
    void assertEqual(T)(T a, T b, string errMessage = "") {
        totalAssertions++;

        if (a == b)
            return;

        if (errMessage.length)
            errorMessages ~= errMessage;
        else
            errorMessages ~= '`' ~ to!string(a) ~ "' does not equal `" ~ to!string(b) ~ '\'';
    }
}

class TestTests : JamuTest {
    this() {
        this.testTarget = "test framework";
    }

    override void test() {
        assertEqual(1, 1);
        assertEqual(true, true);
        assertEqual(1.45, 1.45);
    }
}

