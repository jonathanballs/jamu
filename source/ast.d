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
        string s = ("<INSTRUCTION " ~ to!string(opcode) ~
                to!string(extension) ~ ">");

        foreach(arg; arguments) {
            s ~= "\n    " ~ arg.toString();
        }

        return s;
    }
}

struct Directive {
    DIRECTIVES directive;
    Variant[] arguments;
    NodeMeta meta;

    string toString() {
        string s = ("<DIRECTIVE " ~ to!string(directive) ~ ">");

        foreach(arg; arguments) {
            s ~= "\n    " ~ arg.toString();
        }

        return s;
    }
}

