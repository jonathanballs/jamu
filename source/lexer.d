// Tokens
import std.ascii;
import std.conv;
import std.stdio;
import std.string;

import tokens;
import exceptions;

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

    char peek() {
        if (offset == input.length) {
            return '\0';
        }
        else {
            return input[offset];
        }
    }

    // TODO: support for hexadecimal
    Token lexNumber() {
        string r = "";
        do {
            r ~= next();
        } while(isDigit(peek()));

        return Token(TOK.number, r, this.tokenStartLocation);
    }

    Token lexIdentifier() {
        string r = "";
        do {
            r ~= next();
        } while(isAlphaNum(peek()) || peek() == '_');

        // Check if it is an instruction
        foreach(register; registerStrings) {
            if (r.toLower() == register)
                return Token(TOK.register, r.toLower(), this.tokenStartLocation);
        }

        foreach(instruction; opcodeStrings) {
            if (r.toLower() == instruction)
                return Token(TOK.instruction, r.toLower(), this.tokenStartLocation);
        }

        foreach(directive; assemblerDirectiveStrings) {
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
                    // Log the error and then skip to the next line
                    errors ~= new LexError(tokenStartLocation, 1,
                            "Unexpected character '" ~ next() ~ "'");
                    while (peek() != '\n' && peek() != '\0') { next(); }
                    continue;
            }
        }

        if (errors) {
            throw new LexException(errors);
        }

        return tokens;
    }
}

