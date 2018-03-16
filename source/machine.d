import tokens;
import history;
import instruction;
import std.digest.md;
import std.range.primitives : popBack;

struct MachineConfig {
    uint memorySize = 0x1000;      // 4kb
    uint entryPoint = 0x0;
}

// The main class that represents the state of the machine.
class Machine {
    private uint[16] registers;
    private ubyte[] memory;
    private Cpsr cpsr;
    MachineConfig config;

    Step[] history;
    Action[] currentStep;

    void setMemory(uint start, const ubyte[] data) {

        currentStep ~= Action(ACTIONTYPES.memoryMod, start,
                getMemory(start, cast(uint) data.length).dup, data.dup);

        if (start + data.length >= memory.length) {
            import std.stdio;
            writeln("Tried to set memory to illegal address: ", start,
                    " of length ", data.length);
            return;
        }

        foreach(i, b; data) {
            memory[start+i] = b;
        }
    }

    ubyte[] getMemory(uint start, uint length) {
        if (start+length > config.memorySize) {
            ubyte[] r;
            r.length = length;
            return r;
        }
        return memory[start .. start + length];
    }

    void setRegister(uint regNum, uint value) {
        assert(regNum >= 0 && regNum <= 15);

        // Save change
        currentStep ~= Action(ACTIONTYPES.registerMod, regNum,
                registers[regNum], value);

        // If a PC change then save current step. We should probably
        // make this more explicit :/
        if (regNum == 15) {
            history ~= Step(currentStep.dup);
            currentStep.length = 0;
        }

        registers[regNum] = value;
    }

    void stepBack() {
        if (history.length == 0) {
            return;
        }

        import std.stdio;

        auto step = history[$-1];
        history.popBack();

        foreach(Action action; step.actions) {
            switch(action.type) {
                case ACTIONTYPES.registerMod:
                    registers[action.resourceID] = *cast(uint*)action.originalValue.ptr;
                    continue;
                case ACTIONTYPES.CPSRMod:
                    cpsr = *cast(Cpsr*)action.originalValue.ptr;
                    continue;
                case ACTIONTYPES.memoryMod:
                    writeln(action);
                    foreach(i, b; action.originalValue) {
                        memory[action.resourceID+i] = b;
                    }
                    continue;
                default:
                    assert(0);
            }
        }
    }

    uint getRegister(uint regNum) {
        assert(regNum >= 0 && regNum <= 15);
        return registers[regNum];
    }

    uint[] getRegisters() {
        return registers;
    }

    Cpsr getCpsr() { return cpsr; }
    void setCpsr(Cpsr _cpsr) {
        currentStep ~= Action(ACTIONTYPES.CPSRMod,
                0, *cast(uint*)&cpsr, *cast(uint*)&_cpsr);
        cpsr = _cpsr;
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
        registers[15] = config.entryPoint + 8; // PC
        registers[14] = config.memorySize - 4; // Return address to a nop
        registers[13] = config.memorySize - 4;
        this.config = config;
    }
}

