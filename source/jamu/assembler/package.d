module jamu.assembler;

import std.stdio;
import std.file;
import std.format;
import std.getopt;
import std.variant;
import core.stdc.stdlib;

import jamu.common.elf;
import jamu.assembler.exceptions;
import jamu.assembler.lexer;
import jamu.assembler.parser;
import jamu.assembler.addressResolver;
import jamu.assembler.codeGenerator;

class Assembler {
    static Elf assembleFile(string fileName) {
        auto fileText = readText(fileName);
        auto compiledBytes = assembleString(fileText, fileName);
        // Write output
        return Elf.fromSegmentBytes(compiledBytes);
    }

    static ubyte[] assembleString(string s, string fileName = "") {
        try {
            auto tokens = new Lexer(fileName, s).lex();
            auto program = new Parser(tokens).parse();
            program = new AddressResolver(program).resolve();

            return new CodeGenerator(program).generateCode();

        }
        catch(LexException e) {
            writeln();
            foreach(lexError; e.errors) {
                lexError.printError(s);
                writeln();
            }
            exit(1);
        }
        catch(ParseException e) {
            writeln();
            foreach(parseError; e.errors) {
                parseError.printError(s);
                writeln();
            }
            exit(2);
        }
        catch(TypeException e) {
            writeln();
            foreach(typeError; e.errors) {
                typeError.printError(s);
                writeln();
            }
            exit(3);
        }

        assert(0);
    }
}

