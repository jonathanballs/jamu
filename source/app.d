import std.stdio;
import std.file;
import std.getopt;
import std.variant;

import lexer;

void main(string[] args)
{
    // Temporary just set meadow.s as the default file
    args ~= "testfiles/meadow.s";

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
    auto file = File(filename);
    auto tokens = new Lexer(readText(filename)).lex();
    writeln(tokens);
}

void printHelp() {
    writeln("help :DD");
}

