import tokens;
import history;
import instruction;
import std.digest.md;

struct MachineConfig {
    uint memorySize = 0x10000;      // 64kb
    uint entryPoint = 0x0;
}

// The main class that represents the state of the machine.
class Machine {
    private uint[16] registers;
    private ubyte[] memory;
    private Cpsr cpsr;
    MachineConfig config;

    Step[] History;
    Step[] Future;

    void setMemory(uint start, const ubyte[] data) {
        assert(start + data.length <= memory.length);
        foreach(i, b; data) {
            memory[start+i] = b;
        }
    }

    void setRegister(uint regNum, uint value) {
        assert(regNum >= 0 && regNum <= 15);
        registers[regNum] = value;
    }

    uint getRegister(uint regNum) {
        assert(regNum >= 0 && regNum <= 15);
        return registers[regNum];
    }

    Cpsr getCpsr() { return cpsr; }
    void setCpsr(Cpsr _cpsr) { cpsr = _cpsr; }

    ubyte[] getMemory(uint start, uint length) {
        return memory[start .. start + length];
    }

    uint pc() { return registers[$-1]; }

    override ulong toHash() @trusted {
        auto md5 = new MD5Digest();
        md5.put(cast(ubyte[]) registers);
        md5.put(memory);
        md5.put(*cast(ubyte[4]*)&cpsr);

        ubyte[16] hash = md5.finish();
        return *cast(ulong*)&hash[0];
    }

    this(MachineConfig config) {
        memory.length = config.memorySize;
        registers[15] = config.entryPoint + 8;
        this.config = config;
    }
}

