// Machine history
module jamu.emulator.history;

import jamu.emulator.machine;

enum ACTIONTYPES {
    CPSRMod,
    memoryMod,
    outputMod,
    registerMod,
}

// Represents the changes of a single instruction
struct Step {
    Action[] actions;

    Machine apply(Machine m) { return m; }
    Machine unApply(Machine m) { return m; }
}

struct Action {
    // Details r.e. the modification

    ACTIONTYPES type;
    uint resourceID; // Register number or mem location etc.
    ubyte[] originalValue;
    ubyte[] newValue;

    this(ACTIONTYPES _type, uint _resourceID,
            uint _originalValue, uint _newValue) {
        type = _type;
        resourceID = _resourceID;
        originalValue = (cast(ubyte*)&_originalValue)[0..4].dup;
        newValue = (cast(ubyte*)&_newValue)[0..4].dup;
    }

    this(ACTIONTYPES _type, uint _resourceID,
            ubyte[] _originalValue, ubyte[] _newValue) {
        type = _type;
        resourceID = _resourceID;
        originalValue = _originalValue;
        newValue = _newValue;
    }

    this(ACTIONTYPES _type, uint _resourceID,
            string _originalValue, string _newValue) {
        type = _type;
        resourceID = _resourceID;
        originalValue = cast(ubyte[]) _originalValue;
        newValue = cast(ubyte[]) _newValue;
    }
}

