import std.variant;
import std.stdio;
import std.conv;
import core.stdc.stdlib : exit;

import exceptions;
import tokens;
import ast;

// A simple LL parser
class Parser {
    Token[] tokens;
    int offset;

    ParseError[] errors;

    Token peek() {
        // If the offset has been passed then just return the end of file token
        if (offset >= tokens.length) {
            auto tok = tokens[tokens.length - 1];
            if (tok.type != TOK.eof) {
                return Token(TOK.eof);
            } else {
                return tok;
            }
        } else {
            return tokens[offset];
        }
    }

    Token next() {
        auto t = peek();
        offset++;
        return t;
    }

    private void skipToEndOfLine() {
        while(peek().type != TOK.newline) { next(); }
    }

    this(Token[] tokens) {
        this.tokens = tokens;
    }

    Variant[] parseArguments() {

        Variant[] arguments;
        // Parse arguments list
        wloop: while (true) {
            auto t = peek();
            switch (t.type) {
                // New line only if no arguments
                case TOK.newline:
                     next();
                     break wloop;

                case TOK.label:
                case TOK.integer:
                case TOK.register:
                case TOK.string_:
                    Variant v = next();
                    arguments ~= v;

                    // Next should be comma or newline
                    if (peek().type == TOK.newline) {
                        next();
                        break wloop;
                    } else if (peek().type == TOK.comma) {
                        next();
                        break;
                    } else if (peek().type == TOK.integer
                            || peek().type == TOK.string_
                            || peek().type == TOK.register
                            || peek().type == TOK.label) {
                        errors ~= new ParseError(next(),
                                "Error: Arguments must be separated by" ~
                                " a comma");
                        skipToEndOfLine();
                        break wloop;
                    } else {
                        continue;
                    }

                case TOK.instruction:
                    errors ~= new ParseError(next(),
                            "Error: Instructions must be on separate lines");
                    skipToEndOfLine();
                    break wloop;

                default:
                    errors ~= new ParseError(next(), "Error: A " ~ to!string(t.type)
                            ~ " is not a valid argument");
                    skipToEndOfLine();
                    break wloop;
            }
        }

        return arguments;
    }

    Directive parseDirective() {
        assert(peek().type == TOK.directive);

        auto dir = Directive();

        Token t = next();
        dir.directive = directiveToEnum(t.value);
        dir.meta.tokens ~= t;
        dir.arguments = parseArguments();

        return dir;
    }

    Instruction parseInstruction() {
        assert(peek().type == TOK.instruction);

        auto ins = Instruction();

        // Get instruction meta
        Token t = next();
        auto opc = instruction2Opcode(t.value);
        ins.opcode = opc.opcode;
        ins.extension = opc.extension;
        ins.meta.tokens ~= t;

        ins.arguments = parseArguments();

        return ins;
    }

    Variant[] parse() {
        Variant[] program;

        uint[string] labels;

        while (true) {
            Token t = peek();

            if (t.type == TOK.eof)
                break;

            switch(t.type) {
                case TOK.newline:
                    next();
                    continue;
                case TOK.label:
                    Variant v = Label(next().value);
                    program ~= v;
                    break;
                case TOK.instruction:
                    Variant v = this.parseInstruction();
                    program ~= v;
                    break;
                case TOK.directive:
                    Variant v = this.parseDirective();
                    program ~= v;
                    break;
                default:
                    errors ~= new ParseError(next(),
                            "Error: Line must start with an instruction or label");
                    skipToEndOfLine();
                    continue;
            }
        }

        if (errors) {
            throw new ParseException(errors);
        }

        return program;
    }
}

