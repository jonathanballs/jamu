import tokens;

// The main class that represents the state of the machine.
class Machine {
    uint[REGISTERS.sizeof] registers;
    ubyte[] memory;
    Cpsr cpsr;

    void setMemory(uint start, uint end, ubyte[] data) {
    }

    // Methods for running next instruction
    void next(uint numInsn = 1);
    void prev(uint numInsn = 1);

    uint pc() { return registers[$-1]; }

    this(uint memorySize) {
        memory.length = memorySize;
    }
}

