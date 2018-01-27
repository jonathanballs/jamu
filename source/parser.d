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

    Instruction parseInstruction() {
        assert(peek().type == TOK.instruction);

        auto ins = Instruction();

        // Get instruction meta
        Token t = next();
        auto opc = instruction2Opcode(t.value);
        ins.opcode = opc.opcode;
        ins.extension = opc.extension;
        ins.meta.tokens ~= t;

        // Parse arguments list
        wloop: while (true) {
            t = peek();
            switch (t.type) {
                // New line only if no arguments
                case TOK.newline:
                     next();
                     break wloop;

                case TOK.label:
                case TOK.number:
                case TOK.register:
                    Variant v = next();
                    ins.arguments ~= v;
                    ins.meta.tokens ~= t;

                    // Next should be comma or newline
                    if (peek().type == TOK.newline) {
                        next();
                        break wloop;
                    } else if (peek().type == TOK.comma) {
                        ins.meta.tokens ~= next();
                        break;
                    } else {
                        t = next();
                        writeln("bad second token");
                        goto default;
                    }

                default:
                    writeln(ins);
                    writeln("Unexpected token at " ~ t.toString());
                    assert(0);
            }
        }

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
                    if (t.value == "align") {
                        programOffset += (4 - (programOffset % 4));
                        break;
                    } else if (t.value == "defw") {
                        programOffset += 4;
                        next();
                        next();
                        break;
                    } else if (t.value == "defb") {
                        while(next().type != TOK.newline){}
                        break;
                    }
                    else {
                        writeln("The include directive is not currently supported");
                        exit(1);
                    }
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

