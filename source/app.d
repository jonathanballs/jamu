import std.stdio;
import std.file;
import std.format;
import std.getopt;
import std.variant;

import exceptions;
import lexer;
import parser;
import addressResolver;
import codeGenerator;

void main(string[] args)
{
    // Temporary just set meadow.s as the default file
    if (args.length != 2)
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
    auto fileText = readText(filename);
    try {

        auto tokens = new Lexer(filename, fileText).lex();
        auto program = new Parser(tokens).parse();
        program = new AddressResolver(program).resolve();

        auto compiledCode = new CodeGenerator(program).generateCode();

        // Output the generated code
        import std.digest.digest;
        foreach(i; 0..(compiledCode.length / 4)) {
            write("0x");
            write(format!("%04x")(i*4));
            writeln("    0x", toHexString!(LetterCase.lower)(compiledCode[i*4..(i+1)*4]));
        }
    }
    catch(LexException e) {
        writeln();
        foreach(lexError; e.errors) {
            lexError.printError(fileText);
            writeln();
        }
    }
    catch(ParseException e) {
        writeln();
        foreach(parseError; e.errors) {
            parseError.printError(fileText);
            writeln();
        }
    }
    catch(TypeException e) {
        writeln();
        foreach(typeError; e.errors) {
            typeError.printError(fileText);
            writeln();
        }
    }
}

void printHelp() {
    writeln(
        "usage: jasm <filename>"
    );
}

