module jamu.emulator.types;

import std.bitmanip;
import std.json;
import std.conv;

enum REGISTERS {
    r0, r1, r2, r3,
    r4, r5, r6, r7,
    r8, r9, r10, r11,
    r12, r13, r14, r15
};

enum MODES {
    usr     = 0b10000,  // User
    fiq     = 0b10001,  // FIQ
    irq     = 0b10010,  // IRQ
    spsr    = 0b10011,  // Superuser
    abt     = 0b10111,  // Abort
    und     = 0b11011,  // Undefined
    sys     = 0b11111   // System
}

struct Cpsr {
    mixin(bitfields!(
        bool, "negative",   1,
        bool, "zero",       1,
        bool, "carry",      1,
        bool, "overflow",   1,
        uint, "",           20,
        bool, "disableIRQ", 1,
        bool, "disableFIQ", 1,
        bool, "state",      1,
        MODES,"mode",       5));


    JSONValue toJSON() {
        JSONValue j = [
            "negative":     this.negative,
            "zero":         this.zero,
            "carry":        this.carry,
            "overflow":     this.overflow,
            "disableIRQ":   this.disableIRQ,
            "disableFIQ":   this.disableFIQ,
            "state":        this.state,
        ];

        j["mode"] = this.mode;

        return j;
    }
}

static assert(Cpsr.sizeof == 4);

