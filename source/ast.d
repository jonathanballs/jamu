import std.variant;
import std.stdio;
import std.conv;
import std.format;
import tokens;

struct NodeMeta {
    Token[] tokens;
    Loc location() {
        return tokens[0].location;
    }
}

struct Program {
    Variant[] nodes;
}

struct Instruction {
    OPCODES opcode;
    OPCODE_EXTS extension;
    bool setBit;

    Variant[] arguments;
    NodeMeta meta;

    // ARM instruction size. THUMB is not supported at the moment
    uint address;
    uint size = 4;

    string toString() {
        string s = ("<INSTRUCTION " ~ to!string(opcode) ~
                to!string(extension) ~ ">");
        s = format!"0x%08x "(address) ~ s;

        foreach(arg; arguments) {
            s ~= format!"\n0x%08x     %s"(address, arg.toString());
        }

        return s;
    }
}

struct Directive {
    DIRECTIVES directive;
    Variant[] arguments;
    NodeMeta meta;

    uint address;
    uint size;

    string toString() {
        string s = ("<DIRECTIVE " ~ to!string(directive) ~ " >");
        s = format!"0x%08x "(address) ~ s;

        foreach(arg; arguments) {
            s ~= format!"\n0x%08x     %s"(address, arg.toString());
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
        return "<STRING " ~ this.meta.tokens[0].value ~ " >";
    }
}

struct Integer {
    int value;
    NodeMeta meta;

    string toString() {
        return "<INTEGER " ~ to!string(this.value) ~ " >";
    }
}

struct LabelDef {
    string name;
    NodeMeta meta;
    uint address;

    string toString() {
        auto s = "<LABELDEF " ~ name ~ " >";
        s = format!"0x%08x "(address) ~ s;
        return s;
    }
}

struct LabelExpr {
    string name;
    NodeMeta meta;
    uint address;

    string toString() {
        auto s = "<LABELEXPR " ~ name ~ " >";
        s = format!"0x%08x "(address) ~ s;
        return s;
    }
}

struct Address {
    uint value;
    NodeMeta meta;

    string toString() {
        return "<ADDRESS " ~ format!"0x%08x"(value) ~ " >";
    }
}

