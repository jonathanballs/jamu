module jamu.assembler.exceptions;

import std.conv;
import std.format;
import std.stdio;
import std.string;
import colorize : fg, color, cwrite, cwriteln, cwritefln;

import jamu.assembler.tokens;
import jamu.assembler.ast;

// Helper function to turn tabs into spaces. Harder than it looks because
// a tab has a different size depending on its location
private string tabs2Spaces(string s) pure {
    enum tabLength = 8;
    string r = "";
    foreach (c; s) {
        if (c == '\t') {
            r ~= " ";
            while (r.length % tabLength != 0) { r ~= " "; }
        } else {
            r ~= c;
        }
    }
    return r;
}


class AssemblerError {
    Loc location;
    ulong length = 1;
    string message;
    string exceptionType;

    private void printFileLocation(const ref string fileSource, Loc fileLoc,
            string message = "", fg errorColor = fg.red) {

        // Get line text and replace tabs with spaces
        string lineText = fileSource.split('\n')[fileLoc.lineNumber - 1];
        string lineNumberString = format("%3d | ", fileLoc.lineNumber);
        auto offset = lineText[0..fileLoc.charNumber].tabs2Spaces().length;
        lineText = lineText.tabs2Spaces();

        // Write the line
        cwriteln(lineNumberString.color(fg.blue), lineText);

        // Add annotations
        if (message.length) {
            cwrite("    | ".color(fg.blue));
            writef("%*s", offset, "");
            foreach(i; 0..this.length) {
                cwrite("^".color(errorColor));
            }
            cwriteln((" " ~ message).color(errorColor));
        }
    }

    void printError(string fileSource) {

        cwriteln(("[" ~ exceptionType ~ "] ").color(fg.red), message);
        cwriteln("  --> ".color(fg.blue) ~ this.location.toString());
        cwriteln("    |".color(fg.blue));
        printFileLocation(fileSource, location, message);
    }
}

class LexError : AssemblerError {
    this(Loc location, uint length, string message) {
        this.location = location;
        this.length = length;
        this.message = message;
        this.exceptionType = "Lex Error";
    }
}

class LexException: Exception {
    LexError[] errors;
    this(LexError[] errors, string file = __FILE__, size_t line = __LINE__) {
        this.errors = errors;
        string msg = errors[0].message;
        super(msg, file, line);
    }
}

class ParseError: AssemblerError {
    this(Token t, string message) {
        this.location = t.location;
        this.length = t.value.length;
        this.message = message;
        this.exceptionType = "Parse Error";
    }
}

class ParseException: Exception {
    ParseError[] errors;
    this(ParseError[] errors, string file = __FILE__, size_t line = __LINE__) {
        this.errors = errors;
        string msg = errors[0].message;
        super(msg, file, line);
    }
}

class TypeError: AssemblerError {
    this(Instruction ins, string message) {
        this.location = ins.meta.location;
        this.length = ins.meta.tokens[0].value.length;
        this.message = message;
        this.exceptionType = "Type Error";
    }

    this(Token tok, string message) {
        this.location = tok.location;
        this.length = tok.value.length;
        this.message = message;
        this.exceptionType = "Type Error";
    }
}

class TypeException : Exception {
    TypeError[] errors;
    this(TypeError[] errors, string file = __FILE__, size_t line = __LINE__) {
        this.errors = errors;
        string msg = errors[0].message;
        super(msg, file, line);
    }
}

