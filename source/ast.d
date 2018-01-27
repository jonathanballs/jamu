import std.variant;
import std.stdio;
import std.conv;
import tokens;

struct NodeMeta {
    Token[] tokens;
    Loc location() {
        return tokens[0].location;
    }
}

struct Instruction {
    OPCODES opcode;
    OPCODE_EXTS extension;
    Variant[] arguments;
    NodeMeta meta;

    string toString() {
        string s = "<INS " ~ to!string(opcode);
        if (extension != OPCODE_EXTS.al)
            s ~= to!string(extension);
        foreach(arg; arguments) {
            s ~= " " ~ arg.toString();
        }
        return s ~ ">";
    }
}

struct Directive {
    DIRECTIVES directive;
    Variant[] arguments;
    NodeMeta meta;

    string toString() {
        string s = "<DIR " ~ to!string(directive);
        foreach(arg; arguments) {
            s ~= " " ~ arg.toString();
        }
        return s ~ ">";
    }
}

