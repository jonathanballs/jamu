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
    //uint size() {
        //switch(directive) {
            //case DIRECTIVES.defw:
                //return 4;
            //case DIRECTIVES.defb:
                //uint i;
                //foreach (arg; arguments) {
                    //if (arg.type == typeid(String)) {
                        //i += cast(uint) arg.get!(String).value.length;
                    //} else if (arg.type == typeid(Integer)) {
                        //i += 4;
                    //}
                //}
                //return i;
            //case DIRECTIVES.align_:
                //return 0;
            //case DIRECTIVES.include:
                //return 0;

            //default:
                //assert(0);
        //}

    //}

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

struct Label {
    string name;
    NodeMeta meta;

    uint address;

    string toString() {
        auto s = "<LABEL " ~ name ~ " >";
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

