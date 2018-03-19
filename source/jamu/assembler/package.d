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

Elf assembleFile(string filename) {
    auto fileText = readText(filename);
    try {
        auto tokens = new Lexer(filename, fileText).lex();
        auto program = new Parser(tokens).parse();
        program = new AddressResolver(program).resolve();

        auto compiledCode = new CodeGenerator(program).generateCode();

        // Write output
        return Elf.fromSegmentBytes(compiledCode);
    }
    catch(LexException e) {
        writeln();
        foreach(lexError; e.errors) {
            lexError.printError(fileText);
            writeln();
        }
        exit(1);
    }
    catch(ParseException e) {
        writeln();
        foreach(parseError; e.errors) {
            parseError.printError(fileText);
            writeln();
        }
        exit(2);
    }
    catch(TypeException e) {
        writeln();
        foreach(typeError; e.errors) {
            typeError.printError(fileText);
            writeln();
        }
        exit(3);
    }

    assert(0);
}

