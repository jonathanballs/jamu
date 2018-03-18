import std.stdio;
import std.file;
import std.format;
import std.getopt;
import std.variant;
import core.stdc.stdlib;

import exceptions;
import lexer;
import parser;
import addressResolver;
import codeGenerator;
import elfGenerator;

bool shouldPrintTokens;
void main(string[] args)
{
    string outputFilename = "a.out";
    auto parsedArgs = getopt(args,
            "tokens", &shouldPrintTokens,
            "output", &outputFilename);

    // Print help if requested or if a filename was not given
    if (parsedArgs.helpWanted || args.length == 1) {
        printHelp();
        return;
    }

    // Get the filename of the assembly file
    auto entryFileName = args[1];
    if (!exists(entryFileName)) {
        writeln("No such file " ~ entryFileName);
        return;
    }

    assembleFile(entryFileName, outputFilename);
}

void assembleFile(string filename, string outputFilename) {
    auto fileText = readText(filename);
    try {
        auto tokens = new Lexer(filename, fileText).lex();
        if (shouldPrintTokens) {
            foreach(t; tokens) {
                writeln(t);
            }
        }

        auto program = new Parser(tokens).parse();
        program = new AddressResolver(program).resolve();

        auto compiledCode = new CodeGenerator(program).generateCode();

        // Write output
        new ElfGenerator(compiledCode).writeElfFile(outputFilename);
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
}

void printHelp() {
    writeln(
        "usage: jasm <filename>"
    );
}

