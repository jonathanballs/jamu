import std.conv;
import std.traits;
import std.stdio;
import std.string;

import std.typecons;

static this() {
    // Generate string lists for the opcodes
    foreach (o; [EnumMembers!OPCODES]) {
        opcodeStrings ~= to!string(o);
        foreach(e; [EnumMembers!OPCODE_EXTS]) {
            opcodeStrings ~= to!string(o)~to!string(e);
        }
    }
    foreach (r; [EnumMembers!REGISTERS]) {
        registerStrings ~= to!string(r);
    }
    foreach (d; [EnumMembers!DIRECTIVES]) {
        assemblerDirectiveStrings ~= to!string(d);
    }
}

enum OPCODES {
    adc, add, and, b, bic, bl, bx, cdp,
    cmn, cmp, eor, ldc, ldm, ldr, mcr, mla,
    mov, mrc, mrs, lsr, mul, mvn, orr, rsb,
    rsc, sbc, stc, stm, str, sub, swi, swp,
    teq, tst
};

enum OPCODE_EXTS {
    eq, ne, cs, hs, cc ,lo, mi, pl,
    vs, vc, hi, ls, ge ,lt, gt ,le,
    al,
}

enum REGISTERS {
    r0, r1, r2, r3, r4, r5, r6, r7,
    r8, r9, r10, r11, r12, r13, r14, r15,
    pc
}

enum DIRECTIVES {
    defb, defw, align_, include
}

string[] opcodeStrings;
string[] registerStrings;
string[] assemblerDirectiveStrings;

enum TOK : int {
    comma,
    directive,
    instruction,
    label,
    newline,
    integer,
    register,
    string_,
    eof,
}

enum commentStart = ';';

struct Loc {
    string filename;
    uint lineNumber = 1; // Instead of default 0
    uint charNumber;

    string toString() {
        return filename ~ ":" ~ to!string(lineNumber) ~ ":" ~ to!string(charNumber);
    }
}

struct Token {
    TOK type;
    string value;
    Loc location;

    string toString() {
        string locString = "[" ~ to!string(location.lineNumber) ~
            ":" ~ to!string(location.charNumber) ~ "]";

        string s = "<Token " ~ to!string(this.type) ~ " " ~ locString;

        switch (this.type) {
            case TOK.comma:
            case TOK.newline:
                return s ~ ">";
            default:
                return s ~ " " ~ chomp(this.value) ~ ">";
        }
    }
}

Tuple!(OPCODES, "opcode", OPCODE_EXTS, "extension")
                                instruction2Opcode(string ins) {
    foreach (o; [EnumMembers!OPCODES]) {
        // New extension defaults to always
        if (to!string(o) == ins) {
            return tuple!("opcode", "extension")(o, OPCODE_EXTS.al);
        }

        foreach(e; [EnumMembers!OPCODE_EXTS]) {
            if (to!string(o) ~ to!string(e) == ins) {
                return tuple!("opcode", "extension")(o, e);
            }
        }
    }

    writeln("Unknown ins " ~ ins);
    writeln(opcodeStrings);
    assert(0);
}

DIRECTIVES directiveToEnum(string directive) {
    foreach(d; [EnumMembers!DIRECTIVES]) {
        if (to!string(d) == directive)
            return d;
    }

    assert(0);
}

REGISTERS registerToEnum(string register) {
    foreach(r; [EnumMembers!REGISTERS]) {
        if (to!string(r) == register)
            return r;
    }

    assert(0);
}

