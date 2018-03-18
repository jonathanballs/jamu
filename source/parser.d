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

    Integer parseInteger() {
        assert(peek().type == TOK.integer);
        auto t = next();
        return Integer(to!int(t.value), NodeMeta([t]));
    }

    String parseString() {
        assert(peek().type == TOK.string_);
        auto t = next();
        string s;
        // Convert escape sequences from representations
        // Skip the opening and closing quotations
        bool isEscaping = false;
        foreach(i; 1..t.value.length-1) {
            if (isEscaping) {
                switch (t.value[i]) {
                    case 'n':
                        s ~= '\n';
                        break;
                    case 't':
                        s ~= '\t';
                        break;
                    case '"':
                        s ~= '\"';
                        break;
                    default:
                        errors ~= new ParseError(t, "Error: Invalid escape " ~
                                "sequence '\\" ~ t.value[i] ~ "'");
                }
            } else if (t.value[i] == '\\') {
                isEscaping = true;
            } else {
                s ~= t.value[i];
            }
        }

        return String(s, NodeMeta([t]));
    }

    Register parseRegister() {
        assert(peek().type == TOK.register);
        auto t = next();
        return Register(registerToEnum(t.value), NodeMeta([t]));
    }

    LabelExpr parseLabelExpr() {
        assert(peek().type == TOK.labelExpr);
        auto t = next();
        return LabelExpr(t.value, NodeMeta([t]));
    }

    LabelExpr parseLabelDef() {
        assert(peek().type == TOK.labelDef);
        auto t = next();
        return LabelExpr(t.value[0..$-1], NodeMeta([t]));
    }

    Variant[] parseArguments() {

        Variant[] arguments;
        // Parse arguments list
        wloop: while (true) {
            auto t = peek();
            switch (t.type) {
                case TOK.eof:
                    break wloop;

                // New line only if no arguments
                case TOK.newline:
                     next();
                     break wloop;

                case TOK.string_:
                case TOK.integer:
                case TOK.register:
                case TOK.labelExpr:
                    if (peek().type == TOK.string_) {
                        arguments ~= cast(Variant)parseString();
                    } else if (peek().type == TOK.integer) {
                        arguments ~= cast(Variant)parseInteger();
                    } else if (peek().type == TOK.register) {
                        arguments ~= cast(Variant)parseRegister();
                    } else if (peek().type == TOK.labelExpr) {
                        arguments ~= cast(Variant)parseLabelExpr();
                    } else {
                        assert(0);
                    }

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
                            || peek().type == TOK.labelExpr) {
                        errors ~= new ParseError(next(),
                                "Error: Arguments must be separated by" ~
                                " a comma");
                        skipToEndOfLine();
                        break wloop;
                    } else {
                        // Throw an error
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
        ins.setBit = opc.setBit;
        ins.meta.tokens ~= t;

        ins.arguments = parseArguments();

        return ins;
    }

    Program parse() {
        Variant[] nodes;

        while (true) {
            Token t = peek();

            if (t.type == TOK.eof)
                break;

            switch(t.type) {
                case TOK.newline:
                    next();
                    continue;
                case TOK.labelDef:
                    Variant v = LabelDef(peek().value[0..$-1], NodeMeta([peek()]));
                    next();
                    nodes ~= v;
                    break;
                case TOK.instruction:
                    Variant v = this.parseInstruction();
                    nodes ~= v;
                    break;
                case TOK.directive:
                    Variant v = this.parseDirective();
                    nodes ~= v;
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

        return Program(nodes);
    }
}

