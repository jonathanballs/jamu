module jamu.assembler.lexer;

// Tokens
import std.algorithm : canFind;
import std.ascii;
import std.conv;
import std.stdio;
import std.string;
import std.uni : toLower;

import jamu.assembler.tokens;
import jamu.assembler.exceptions;

class Lexer {
    string input;
    uint offset;

    // Updated by next()
    Loc location;
    Loc tokenStartLocation;

    // Errors
    LexError[] errors;

    this(string fileName, string input) {
        this.location.fileName = fileName;
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

        offset++;
        return c;
    }

    char peek(int n = 1) {
        n -= 1;

        if (offset + n >= cast(uint)input.length) {
            return '\0';
        }
        else {
            return input[offset + n];
        }
    }

    // In the case of errors we should just skip to the end of the line and
    // keep on lexing.
    private void skipToEndOfLine() {
        while (peek() != '\n' && peek() != '\0') { next(); }
    }

    // Supports 0x, 0b and base 10
    // Supports character literals
    // Todo negative numbers
    Token lexInteger() {
        auto base = 10;
        string r;

        // Used to indicate a literal
        if (peek() == '#')
            next();

        if (peek() == '\'') { // A character literal

            if (peek(2) == '\\' && peek(4) == '\'') { // Escape sequence
                switch(peek(3)) {
                case 'n':
                case 't':
                case '"':
                case '\'':
                    r ~= next(); r ~= next();
                    r ~= next(); r ~= next();
                    return Token(TOK.charLiteral, r, this.tokenStartLocation);
                default:
                    errors ~= new LexError(tokenStartLocation, 4,
                            "Invalid escape sequence");
                    skipToEndOfLine();
                    return Token();
                }
            } else if (isPrintable(peek(2)) && peek(3) == '\'') { // Normal ASCII
                r ~= next(); r ~= next();
                r ~= next(); r ~= next();
                return Token(TOK.charLiteral, r, this.tokenStartLocation);
            } else {
                errors ~= new LexError(tokenStartLocation, 3,
                        "Character literals must be as single character of ascii only");
                skipToEndOfLine();
                return Token();
            }

            assert(0);
        }

        if (peek() == '0') {
            switch(peek(2)) {
                case 'x':
                case 'X':
                    base = 16;
                    r ~= next(); r ~= next();
                    break;
                case 'b':
                case 'B':
                    base = 2;
                    r ~= next(); r ~= next();
                    break;
                case '0': .. case '9':
                    errors ~= new LexError(tokenStartLocation, 2,
                            "Decimal numbers may not start with preceding zeros");
                    skipToEndOfLine();
                    return Token();
                default:
                    // It's just a zero
                    break;
            }
        }

        do {
            char c = peek();
            if (base == 10) {
                if (isDigit(c)) {
                    r ~= next();
                } else break;
            } else if (base == 16) {
                if (isHexDigit(c)) {
                    r ~= next();
                } else break;
            } else if (base == 2) {
                if (c == '0' || c == '1') {
                    r ~= next();
                } else break;
            } else { assert(0); }
        } while (true);

        return Token(TOK.integer, r, this.tokenStartLocation);
    }

    Token lexIdentifier() {
        string r = "";
        do {
            r ~= next();
        } while(isAlphaNum(peek()) || peek() == '_');

        // Check if it's a keyword otherwise it's a label
        if (r.toLower() in keywordTokens) {
            auto t = keywordTokens[r.toLower()];
            t.location = this.tokenStartLocation;
            return t;
        } else if (peek() == ':') {
            r ~= next();
            return Token(TOK.labelDef, r, this.tokenStartLocation);
        } else {
            return Token(TOK.labelExpr, r, this.tokenStartLocation);
        }
    }

    Token lexDirective() {
        assert(peek() == '.');
        string r = "" ~ next();
        do {
            r ~= next();
        } while(isAlphaNum(peek()) || peek() == '_');

        auto directiveName = r[1..$].toLower();

        if (directiveStrings.canFind(directiveName)) {
            return Token(TOK.directive, r, this.tokenStartLocation);
        } else {
            errors ~= new LexError(tokenStartLocation, cast(uint)r.length,
                    "Error: Invalid directive");
            return Token();
        }
    }

    Token lexString() {
        assert(peek() == '"');

        string r = "" ~ next();

        bool isEscaping = false;

        while (true) {
            char c = next();
            r ~= c;

            if (c == '\n') {
                errors ~= new LexError(tokenStartLocation, 1,
                        "Error: Strings may not run over multiple lines");
                break;
            } else if (c == '\0') {
                errors ~= new LexError(tokenStartLocation, 1,
                        "Error: This string has not been terminated");
                break;
            }

            if (isEscaping) {
                isEscaping = false;
            } else {
                if (c == '\\')
                    isEscaping = true;
                else if (c == '\"')
                    break;
            }
        }

        return Token(TOK.string_, r, this.tokenStartLocation);
    }

    Token[] lex() {
        Token[] tokens;

        while(true) {
            char c = peek();
            this.tokenStartLocation = location;

            if (!c) {
                tokens ~= Token(TOK.eof, to!string(c), tokenStartLocation);
                break;
            }

            switch(c) {
                // Single character tokens
                case ',':
                    tokens ~= Token(TOK.comma, to!string(next()),
                            this.tokenStartLocation);
                    break;
                case '[':
                    tokens ~= Token(TOK.openBracket, to!string(next()),
                            this.tokenStartLocation);
                    break;
                case ']':
                    tokens ~= Token(TOK.closeBracket, to!string(next()),
                            this.tokenStartLocation);
                    break;
                case '!':
                    tokens ~= Token(TOK.exclamationMark, to!string(next()),
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
                case ';': // Comments. Remember to log end of line
                    while(peek() != '\n' && peek() != '\0') { next(); }
                    break;
                case '0': ..  case '9':
                    tokens ~= lexInteger();
                    break;
                case '#':
                    if (('0' <= peek(2) && peek(2) <= '9') || peek(2) == '\'') {
                        tokens ~= lexInteger();
                    } else {
                        next();
                        writeln("Error unexpected char after #: " ~ next());
                    }
                    break;
                case '.':
                    tokens ~= lexDirective();
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
                    // Log the error and then skip to the next line
                    errors ~= new LexError(tokenStartLocation, 1,
                            "Unexpected character '" ~ next() ~ "'");
                    skipToEndOfLine();
                    continue;
            }
        }

        if (errors) {
            throw new LexException(errors);
        }

        return tokens;
    }
}

