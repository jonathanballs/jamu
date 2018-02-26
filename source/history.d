// Machine history
import machine;

enum ACTIONTYPES {
    registerMod,
    memoryMod,
    CPSRMod,
}

// Represents the changes of a single instruction
struct Step {
    uint instructionAddress;

    private Action[] actions;

    Machine apply(Machine m) { return m; }
    Machine unApply(Machine m) { return m; }
}

struct Action {
    // Details r.e. the modification

    ACTIONTYPES type;
    uint resourceID;
    ubyte[] originalValue;

    Machine apply(Machine m) {
        return m;
    }

    Machine unApply(Machine m) {
        return m;
    }
}

