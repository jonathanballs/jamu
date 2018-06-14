module jamu.assembler.tokens;

import std.algorithm : canFind;
import std.conv;
import std.traits;
import std.stdio;
import std.string;

import std.typecons;

Token[string] keywordTokens;
string[] directiveStrings;

static this() {
    // Generate string lists for the opcodes
    foreach (o; [EnumMembers!OPCODES]) {
        auto opcodeString = to!string(o);
        keywordTokens[opcodeString] = Token(TOK.instruction, opcodeString);

        // Opcode conditions
        foreach(e; [EnumMembers!OPCODE_EXTS]) {
            auto condString = to!string(e);
            keywordTokens[opcodeString ~ condString] =
                Token(TOK.instruction, opcodeString ~ condString);
        }

        // Data processing instruction extensions
        if (dataProcessingOpcodes.canFind(o)) {
            keywordTokens[opcodeString ~ "s"] =
                Token(TOK.instruction, opcodeString ~ "s");

            // Opcode conditions
            foreach(e; [EnumMembers!OPCODE_EXTS]) {
                auto condString = to!string(e);
                keywordTokens[opcodeString ~ "s" ~ condString] =
                    Token(TOK.instruction, opcodeString ~ "s" ~ condString);
            }
        }
    }

    foreach (r; [EnumMembers!REGISTERS]) {
        auto registerString = to!string(r);
        keywordTokens[registerString] = Token(TOK.register, registerString);
    }

    foreach (d; [EnumMembers!DIRECTIVES]) {
        auto directiveString = to!string(d);
        if (d == DIRECTIVES.align_) {
            directiveString = "align";
        }

        directiveStrings ~= directiveString;
    }
}

enum OPCODES {
    adc, add, and, b, bic, bl, bx, cdp,
    cmn, cmp, eor, ldc, ldm, ldr, mcr, mla,
    mov, mrc, mrs, lsr, mul, mvn, orr, rsb,
    rsc, sbc, stc, stm, str, sub, swi, swp,
    teq, tst,
    // Pseudo instructions
    adr,
};

OPCODES[] dataProcessingOpcodes = [
    OPCODES.and, OPCODES.eor, OPCODES.sub, OPCODES.rsb,
    OPCODES.add, OPCODES.adc, OPCODES.sbc, OPCODES.rsc,
    OPCODES.tst, OPCODES.teq, OPCODES.cmp, OPCODES.cmn,
    OPCODES.orr, OPCODES.mov, OPCODES.bic, OPCODES.mvn,
];

enum OPCODE_EXTS {
    eq, ne, cs, cc, mi, pl, vs, vc,
    hi, ls, ge, lt, gt, le, al
}

enum REGISTERS {
    r0, r1, r2, r3, r4, r5, r6, r7,
    r8, r9, r10, r11, r12, r13, r14, r15,
    pc
}

enum DIRECTIVES {
    defb, defw, align_, include
}

enum TOK : int {
    comma,
    directive,
    eof,
    expr,
    instruction,
    integer,
    labelDef,
    labelExpr,
    newline,
    register,
    string_,
    openBracket,
    closeBracket,
    exclamationMark,
}

enum commentStart = ';';

struct Loc {
    string fileName;
    uint lineNumber = 1; // Instead of default 0
    uint charNumber;

    string toString() {
        return fileName ~ ":" ~ to!string(lineNumber) ~ ":" ~ to!string(charNumber);
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

Tuple!(OPCODES, "opcode", OPCODE_EXTS, "extension", bool, "setBit")
                                instruction2Opcode(string ins) {
    foreach (o; [EnumMembers!OPCODES]) {
        // New extension defaults to always
        auto opcodeString = to!string(o);
        if (opcodeString == ins) {
            return tuple!("opcode", "extension", "setBit")(o, OPCODE_EXTS.al, false);
        }

        foreach(e; [EnumMembers!OPCODE_EXTS]) {
            if (opcodeString ~ to!string(e) == ins) {
                return tuple!("opcode", "extension", "setBit")(o, e, false);
            }
        }

        // Data processing instruction setbits
        if (opcodeString ~ "s" == ins) {
            return tuple!("opcode", "extension", "setBit")(o, OPCODE_EXTS.al, true);
        }

        foreach(e; [EnumMembers!OPCODE_EXTS]) {
            if (opcodeString ~ "s" ~ to!string(e) == ins) {
                return tuple!("opcode", "extension", "setBit")(o, e, true);
            }
        }
    }

    writeln("Unknown ins " ~ ins);
    assert(0);
}

DIRECTIVES directiveToEnum(string directive) {
    directive = directive.toLower();
    if (directive == ".align") {
        return DIRECTIVES.align_;
    }

    foreach(d; [EnumMembers!DIRECTIVES]) {
        if ('.' ~ to!string(d) == directive)
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

