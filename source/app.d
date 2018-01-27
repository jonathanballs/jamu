import std.stdio;
import std.file;
import std.getopt;
import std.variant;

import exceptions;
import lexer;
import parser;

void main(string[] args)
{
    // Temporary just set meadow.s as the default file
    args ~= "testfiles/meadowbad.s";

    auto parsedArgs = getopt(args);

    // Print help if requested or if a filename was not given
    if (parsedArgs.helpWanted || args.length != 2) {
        printHelp();
        return;
    }

    // Get the filename of the assembly file
    auto entryFileName = args[1];
    if (!exists(entryFileName)) {
        writeln("No such file " ~ entryFileName);
        return;
    }

    parseFile(entryFileName);
}

void parseFile(string filename) {
    auto fileText = readText(filename);
    try {
        auto tokens = new Lexer(filename, fileText).lex();
        auto program = new Parser(tokens).parse();
        foreach(p; program) {
            writeln(p);
        }
    }
    catch(LexException e) {
        foreach(lexError; e.errors) {
            lexError.printError(fileText);
        }
    }
}

void printHelp() {
    writeln("help :DD");
}

