import tokens;

// Base class for a decompiled instruction that can be
// excecuted
abstract class Instruction {
    ubyte[4] source;
    string decompiled;

    void execute();
    void executeBackwards();
}

