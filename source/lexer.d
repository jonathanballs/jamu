// Tokens
import std.ascii;
import std.conv;
import std.stdio;
import std.string;

static this() {
    foreach(o; opcodes) {
        instructions ~= o;
        foreach(e; opcodeExtensions) {
            instructions ~= o~e;
        }
    }
}

string[] opcodes = [
    "adc", "add", "adr", "and",
    "b", "bic", "bl", "bx",
    "cdp", "cmn", "cmp", "eor",
    "ldc", "ldm", "ldr", "mcr",
    "mla", "mov", "mrc", "mrs",
    "msr", "mul", "mvn", "orr",
    "rsb", "rsc", "sbc", "stc",
    "stm", "str", "sub", "swi",
    "swp", "teq", "tst",
];

string[] opcodeExtensions = [
    "eq", "ne", "cs", "hs",
    "cc ", "lo ", "mi ", "pl",
    "vs ", "vc ", "hi ", "ls",
    "ge ", "lt ", "gt ", "le",
    "al"
];

string[] instructions; // combination of all opcodes and extensions

string[] registerNames = [
    "r0", "r1", "r2", "r3",
    "r4", "r5", "r6", "r7",
    "r8", "r9", "r10", "r11",
    "r12", "r13", "r14", "r15",
    "pc"
];

string[] assemblerDirectives = [
    "defb", "defw", "align", "include"
];

enum TOK : int {
    comma,
    directive,
    instruction,
    label,
    newline,
    number,
    register,
    string_,
}

enum commentStart = ';';

struct Loc {
    string filename;
    uint lineNumber = 1; // Instead of default 0
    uint charNumber;
}

struct Token {
    TOK type;
    string value;
    Loc location;

    string toString() {
        string locString = "[" ~ to!string(location.lineNumber) ~
            ":" ~ to!string(location.charNumber) ~ "]";

        string r = "<Token " ~ to!string(this.type) ~ " " ~ locString;

        switch (this.type) {
            case TOK.comma:
            case TOK.newline:
                return r ~ ">";
            default:
                return r ~ " " ~ this.value ~ ">";
        }
    }
}

class Lexer {
    string input;
    uint position;

    // Updated by next()
    Loc location;
    Loc tokenStartLocation;

    this(string input) {
        this.input = input;
    }

    char next() {
        char c = peek();
        if (c == '\n') {
            location.lineNumber++;
            location.charNumber = 0;
        } else {
            location.charNumber++;
        }

        position++;
        return c;
    }

    char peek() {
        if (position == input.length) {
            return '\0';
        }
        else {
            return input[position];
        }
    }

    // TODO: support for hexadecimal
    Token lexNumber() {
        string r = "";
        do {
            r ~= next();
        } while('0' <= peek() && peek() <= '9');

        return Token(TOK.number, r, this.tokenStartLocation);
    }

    Token lexIdentifier() {
        string r = "";
        do {
            r ~= next();
        } while(isAlphaNum(peek()) || peek() == '_');

        // Check if it is an instruction
        foreach(register; registerNames) {
            if (r.toLower() == register)
                return Token(TOK.register, r.toLower(), this.tokenStartLocation);
        }

        foreach(instruction; instructions) {
            if (r.toLower() == instruction)
                return Token(TOK.instruction, r.toLower(), this.tokenStartLocation);
        }

        foreach(directive; assemblerDirectives) {
            if (r.toLower() == directive)
                return Token(TOK.directive, r.toLower(), this.tokenStartLocation);
        }

        return Token(TOK.label, r, this.tokenStartLocation);
    }

    // TODO: handle escape sequences
    // TODO: handle dangling strings properly
    Token lexString() {
        string r = "";
        do {
            r ~= next();
        } while (peek() != '"');
        r ~= next();

        return Token(TOK.string_, r, this.tokenStartLocation);
    }

    Token[] lex() {
        Token[] tokens;

        while(true) {
            char c = peek();
            if (!c) {
                break;
            }

            this.tokenStartLocation = location;

            switch(c) {
                // Single character tokens
                case ',':
                    tokens ~= Token(TOK.comma, to!string(next()),
                            this.tokenStartLocation);
                    break;
                // Newlines
                case '\n':
                    tokens ~= Token(TOK.newline, to!string(next()),
                            this.tokenStartLocation);
                    break;
                case ' ': // Whitespace
                case '\t':
                    while (peek() == ' ' || peek() == '\t') { next(); }
                    break;
                case ';': // Comments
                    while(next() != '\n'){}
                    break;
                case '0': // Numbers
                ..
                case '9':
                    tokens ~= lexNumber();
                    break;
                case '#':
                    next();
                    if ('0' <= peek() && peek() <= '9') {
                        tokens ~= lexNumber();
                    } else {
                        writeln("Error unexpected char after #: " ~ next());
                    }
                    break;

                // Identifiers
                case 'a': .. case 'z':
                case 'A': .. case 'Z':
                    tokens ~= lexIdentifier();
                    break;

                // Strings
                case '"':
                    tokens ~= lexString();
                    break;

                default:
                    writeln("Error unexpected char " ~ next());
            }
        }

        return tokens;
    }
}

