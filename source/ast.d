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
        string s = ("<DIRECTIVE " ~ to!string(directive) ~ " >");

        foreach(arg; arguments) {
            s ~= "\n    " ~ arg.toString();
        }

        return s;
    }
}

struct Register {
    REGISTERS register;
    NodeMeta meta;

    string toString() {
        return "<REGISTER " ~ to!string(this.register) ~ " >";
    }
}

struct String {
    string value;
    NodeMeta meta;

    string toString() {
        return "<STRING \"" ~ this.meta.tokens[0].value ~ "\" >";
    }
}

struct Integer {
    int value;
    NodeMeta meta;

    string toString() {
        return "<INTEGER " ~ to!string(this.value) ~ " >";
    }
}

struct Label {
    string name;

    string toString() {
        return "<LABEL " ~ name ~ " >";
    }
}

