import std.variant;
import std.stdio;
import core.stdc.stdlib : exit;

import tokens;
import ast;

// A simple LL parser
class Parser {
    Token[] tokens;
    int offset;

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
                case TOK.number:
                case TOK.register:
                case TOK.string_:
                    Variant v = next();
                    arguments ~= v;
                    //ins.meta.tokens ~= t;

                    // Next should be comma or newline
                    if (peek().type == TOK.newline) {
                        next();
                        break wloop;
                    } else if (peek().type == TOK.comma) {
                        /*ins.meta.tokens ~= */next();
                        break;
                    } else {
                        t = next();
                        writeln("bad second token");
                        goto default;
                    }

                default:
                    writeln(tokens);
                    writeln(arguments);
                    writeln("Unexpected token at " ~ t.toString());
                    assert(0);
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
        uint programOffset; // Number of bytes deep into parsing. This is used
                            // for evaluating labels.

        while (true) {
            Token t = peek();

            if (t.type == TOK.eof)
                break;

            switch(t.type) {
                case TOK.newline:
                    next();
                    continue;
                case TOK.label:
                    // Add label to label list
                    // TODO: Check that label is not defined
                    labels[next().value] = programOffset;
                    break;
                case TOK.instruction:
                    Variant v = this.parseInstruction();
                    program ~= v;
                    programOffset += 4; // ARM instruction size

                    break;
                case TOK.directive:
                    Variant v = this.parseDirective();
                    program ~= v;
                    break;
                default:
                    writeln(tokens);
                    writeln(program);
                    writeln("Unexpected token " ~ t.toString());
                    assert(0);
            }
        }

        return program;
    }
}

