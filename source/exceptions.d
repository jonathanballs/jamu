import std.conv;
import std.stdio;
import std.string;
import colorize : fg, color, cwrite, cwriteln, cwritefln;

import tokens;

class AssemblerError {
    Loc location;
    uint length;
    string message;

    void printError(string fileSource) {
        // Print location in source
        string lineNumber = to!string(location.lineNumber) ~ " | ";
        string lineText = fileSource
            .split('\n')[location.lineNumber - 1];

        // Get offset and replace tabs with spaces
        auto messageOffset = lineNumber.length +
            lineText[0 .. location.charNumber].replace("\t", "    ").length;
        lineText = lineText.replace("\t", "    ");

        cwriteln("[Lex Error] ".color(fg.red), message);
        cwriteln(" --> ".color(fg.blue) ~ this.location.toString());
        cwriteln(lineNumber.color(fg.blue), lineText);

        writef("%*s", messageOffset, "");
        foreach(i; 0 .. this.length) {
            cwrite("^".color(fg.red));
        }
        cwriteln(" ", message.color(fg.red));
    }
}

class LexError : AssemblerError {
    this(Loc location, uint length, string message) {
        this.location = location;
        this.length = length;
        this.message = message;
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

