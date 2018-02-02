import tokens;

struct MachineConfig {
    uint memorySize = 0x10000;      // 64kb
}

// The main class that represents the state of the machine.
class Machine {
    uint[REGISTERS.sizeof] registers;
    ubyte[] memory;
    Cpsr cpsr;

    void setMemory(uint start, const ubyte[] data) {
        assert(start + data.length <= memory.length);
        foreach(i, b; data) {
            memory[start+i] = b;
        }
    }

    // Methods for running next instruction
    //void next(uint numInsn = 1);
    //void prev(uint numInsn = 1);

    uint pc() { return registers[$-1]; }

    this(MachineConfig config) {
        memory.length = config.memorySize;
    }
}

