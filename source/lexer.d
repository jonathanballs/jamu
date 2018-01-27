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
    "adc", "add", "and", "b",
    "bic", "bl", "bx", "cdp",
    "cmn", "cmp", "eor", "ldc",
    "ldm", "ldr", "mcr", "mla",
    "mov", "mrc", "mrs", "msr",
    "mul", "mvn", "orr", "rsb",
    "rsc", "sbc", "stc", "stm",
    "str", "sub", "swi", "swp",
    "teq", "tst",
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

enum TOK : int {
    comma,
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
    uint lineNumber;
    uint charNumber;
}

struct Token {
    TOK type;
    string value;

    string toString() {
        switch (this.type) {
            case TOK.comma:
            case TOK.newline:
                return "<Token: " ~ to!string(this.type) ~ ">";
            default:
                return "<Token: " ~ to!string(this.type) ~ " (" ~ this.value ~ ")>";
        }
    }
}

class Lexer {
    string input;
    uint position;

    this(string input) {
        this.input = input;

    }

    char next() {
        char c = peek();
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

        return Token(TOK.number, r);
    }

    Token lexIdentifier() {
        string r = "";
        do {
            r ~= next();
        } while(isAlphaNum(peek()) || peek() == '_');

        // Check if it is an instruction
        foreach(register; registerNames) {
            if (r.toLower() == register)
                return Token(TOK.register, r);
        }

        foreach(instruction; instructions) {
            if (r.toLower() == instruction)
                return Token(TOK.instruction, r);
        }

        return Token(TOK.label, r);
    }

    // TODO: handle escape sequences
    Token lexString() {
        string r = "";
        do {
            r ~= next();
        } while (peek() != '"');
        r ~= next();

        return Token(TOK.string_, r);
    }

    Token[] lex() {
        Token[] tokens;

        while(true) {
            char c = peek();
            if (!c) {
                break;
            }

            switch(c) {
                // Single character tokens
                case ',':
                    tokens ~= Token(TOK.comma, to!string(next()));
                    break;
                // Newlines
                case '\n':
                    tokens ~= Token(TOK.newline, to!string(next()));
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

