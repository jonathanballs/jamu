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

struct AssemblerOptions {
    bool printTokens;
    bool printSyntaxTree;
    bool printSymbolTable;
}

class Assembler {

    static Elf assembleFile(string fileName,
            AssemblerOptions options = AssemblerOptions()) {

        auto fileText = readText(fileName);
        auto compiledBytes = assembleString(fileText, fileName);
        // Write output
        return Elf.fromSegmentBytes(compiledBytes);
    }

    static ubyte[] assembleString(string s,
        string fileName = "",
        AssemblerOptions options = AssemblerOptions()) {

        auto tokens = new Lexer(fileName, s).lex();
        if (options.printTokens) {
        }

        auto program = new Parser(tokens).parse();
        program = new AddressResolver(program).resolve();

        return new CodeGenerator(program).generateCode();
    }
}

