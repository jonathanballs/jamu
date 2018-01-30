import std.conv;
import std.variant;
import std.stdio;
import tokens;
import ast;
import exceptions;

class AddressResolver {

    Program program;

    TypeError[] errors;

    this(Program program_) {
        program = program_;
    }

    Program resolve() {
        Program resolvedProgram;
        Label[string] labels;
        // Step one get a list of all labels

        uint currentAddress;
        foreach(ref node; program.nodes) {
            if (node.type == typeid(Label)) {
                auto label = node.get!(Label);
                label.address = currentAddress;
                resolvedProgram.nodes ~= cast(Variant)label;

                if (label.name !in labels) {
                    labels[label.name] = label;
                } else {
                    errors ~= new TypeError(label.meta.tokens[0],
                            "Error: Label '" ~ label.name ~ "' was already"
                            ~ " defined on line "
                            ~ to!string(labels[label.name].meta.location.lineNumber));
                }

            } else if (node.type == typeid(Instruction)) {

                auto ins = node.get!(Instruction);
                ins.address = currentAddress;
                currentAddress += 4;
                resolvedProgram.nodes ~= cast(Variant)ins;

            } else if (node.type == typeid(Directive)) {
                auto dir = node.get!(Directive);
                dir.address = currentAddress;
                resolvedProgram.nodes ~= cast(Variant)dir;

                if (dir.directive == DIRECTIVES.defw) {
                    currentAddress += 4;
                } else if (dir.directive == DIRECTIVES.defb) {
                    uint directiveSize;
                    foreach(arg; dir.arguments) {
                        if (arg.type == typeid(String)) {
                            auto argS = arg.get!(String);
                            directiveSize += cast(uint)argS.value.length;
                        } else if (arg.type == typeid(Integer)) {
                            // One byte
                            directiveSize += 1;
                        }
                    }
                    currentAddress += directiveSize;
                } else if (dir.directive == DIRECTIVES.align_) {
                    // Round up to nearerst four
                    writeln(currentAddress);
                    currentAddress += 4 - (currentAddress % 4);
                }
            } else {
                // Should have been caught by the parser.
                assert(0);
            }
        }

        if (errors) {
            throw new TypeException(errors);
        }

        return resolvedProgram;
    }
}

