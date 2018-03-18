module jamu.assembler.lexer;

// Tokens
import std.ascii;
import std.conv;
import std.stdio;
import std.string;
import std.algorithm : canFind;

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

    this(string filename, string input) {
        this.location.filename = filename;
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

    // TODO: support for hexadecimal
    Token lexNumber() {
        string r = "";
        do {
            r ~= next();
        } while(isDigit(peek()));

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

        return Token(TOK.directive, r, this.tokenStartLocation);
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

