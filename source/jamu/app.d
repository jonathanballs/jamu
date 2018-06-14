import std.conv;
import std.getopt;
import std.stdio;
import std.string;
import std.json;
import std.algorithm.mutation: reverse;
import std.algorithm: canFind;
import core.stdc.stdlib;

import jamu.emulator.machine;
import jamu.emulator.instruction;
import jamu.assembler;
import jamu.assembler.exceptions;

import jamu.common.elf;

struct EmulatorConfig
{
    bool jsonInterface;
    string fileName;
}

struct EmulatorCommand
{
    string cmd;
    string[] args;
}

void main(string[] args)
{
    // Command line argument parsing. First check whether jamu is launched in
    // assembler mode or emulator mode.
    bool assembleMode = false;
    if (args.canFind("-a") || args.canFind("--assemble"))
        assembleMode = true;

    if (assembleMode) { // Assembler mode
        string outputFilename = "a.out";
        string inputFilename;
        AssemblerOptions options;

        try
        {
            getopt(args,
                    "output|o", &outputFilename,
                    "tokens|t", &options.printTokens,
                    "ast|a", &options.printSyntaxTree,
                    "symbols|s", &options.printSymbolTable
                    );

            if (args.length != 2) {
                throw new Exception("Please specify a single filename in "
                        ~ "your command line arguments");
            }
            else
            {
                inputFilename = args[1];
            }

        }
        catch (Exception e)
        {
            writeError(e.message.dup, false);
            writeln();
            printHelpAndExit();
        }


        try
        {
            auto elf = Assembler.assembleFile(inputFilename, options);
            elf.writeFile(outputFilename);
        }
        catch(LexException e) {
            writeln();
            foreach(lexError; e.errors) {
                lexError.printError();
                writeln();
            }
            exit(2);
        }
        catch(ParseException e) {
            writeln();
            foreach(parseError; e.errors) {
                parseError.printError();
                writeln();
            }
            exit(2);
        }
        catch(TypeException e) {
            writeln();
            foreach(typeError; e.errors) {
                typeError.printError();
                writeln();
            }
            exit(2);
        }
    }
    else
    { // Emulator mode
        EmulatorConfig emuConf;
        MachineConfig machineConf;

        try
        {
            getopt(args, "json", &emuConf.jsonInterface);
            if (args.length == 2)
            {
                emuConf.fileName = args[1];
            }
        }
        catch (Exception e)
        {
            writeError(e.message.dup, false);
            writeln();
            printHelpAndExit();
        }

        Machine machine = new Machine(machineConf);
        if (emuConf.fileName)
            machine.loadElf(Elf.readFile(emuConf.fileName));

        // Set output to line buffering for json output
        if (emuConf.jsonInterface)
        {
            stdout.setvbuf(0, 2);
        }

        runLoop(machine, emuConf);
    }
}

// Parse a command agnostically to input syntax.
// load_elf a.out
// { "cmd": "load_elf", "args": ["a.out"] }
EmulatorCommand parseCommand(string command, bool json) {
    EmulatorCommand parsedCommand;
    if (json) {
        auto j = parseJSON(command);
        parsedCommand.cmd = j["cmd"].str;

        if (const(JSONValue)* args = "args" in j) {
            foreach(JSONValue a; j["args"].array) {
                if (a.type() == JSON_TYPE.STRING) {
                    parsedCommand.args ~= a.str;
                } else {
                    parsedCommand.args ~= to!string(a.integer);
                }
            }
        }
    } else {
        auto l = command.chomp().split(" ");
        if (!l.length) { // Return an empty command.
            parsedCommand.cmd = "repeat";
        } else {
            parsedCommand.cmd = l[0];
            parsedCommand.args = l[1..$];
        }
    }

    return parsedCommand;
}

void writeError(string errorMessage, bool json = false) {
    if (json) {
        JSONValue j = ["error": errorMessage];
        writeln(j);
    } else {
        import colorize : fg, color, cwrite;
        cwrite("Error: ".color(fg.red));
        writeln(errorMessage);
    }
}

void runLoop(Machine machine, EmulatorConfig emuConf) {

    //if (!emuConf.jsonInterface)
        //printMachineStatus(&machine, emuConf);

    EmulatorCommand previousCommand = EmulatorCommand("step");

    while (true) {

        // Display user prompt if not json interface
        if (!emuConf.jsonInterface) {
            import colorize : fg, color, cwrite;
            cwrite(">>> ".color(fg.green));
        }

        EmulatorCommand command;
        try {
            command = parseCommand(readln(), emuConf.jsonInterface);
        } catch (Exception e) {
            writeError("Unable to understand command passed to jamu.",
                    emuConf.jsonInterface);
            continue;
        }

        // The repeat command will repeat the last command. If it's the first
        // command then it will default to step (see instantiation of
        // previosuCommand).
        if (command.cmd == "repeat") {
            command = previousCommand;
        } else {
            previousCommand = command;
        }

        // These commands are just for development for now. Time will be spent
        // trying to make them more intuitive
        switch(command.cmd) {
            case "exit":
            case "quit":
                return;
            case "info":
                JSONValue j = [
                    "mem_size": machine.config.memorySize,
                    "pc": machine.pc(),
                    "machine_hash": machine.toHash(),
                    "history_size": machine.history.length,
                ];
                writeln(j);

                continue;

            case "reg":
            case "registers":
                JSONValue j = [ "register_values": machine.getRegisters() ];
                writeln(j);
                continue;

            case "cpsr":
                JSONValue j = machine.getCpsr().toJSON();
                writeln(j);
                continue;

            case "mem":
            case "memory":
                if (!command.args.length) {
                    writeError("usage: mem start_loc, length", emuConf.jsonInterface);
                    continue;
                }

                uint startLoc = to!uint(command.args[0]) & 0xfffffffc;
                if (startLoc > machine.config.memorySize - 4) {
                    startLoc = machine.config.memorySize - 4;
                }
                uint memLength = command.args.length > 1
                    ? to!int(command.args[1])
                    : 64;

                if (startLoc + memLength >= machine.config.memorySize) {
                    memLength = machine.config.memorySize - startLoc;
                }

                ubyte[] mem = machine.getMemory(startLoc, memLength);

                if (emuConf.jsonInterface) {
                    JSONValue j = [
                        "start_address": startLoc,
                        "block_length": memLength
                    ];
                    j["memory"] = mem;
                    writeln(j);
                } else {
                    import std.digest;
                    foreach(i; 0..(mem.length / 4)) {
                        write("0x", format!("%04x")(startLoc + i*4));
                        writeln("  0x", toHexString!(LetterCase.lower)(mem[i*4..(i+1)*4]));
                    }
                }

                continue;

            case "back":
            case "prev":
                machine.stepBack();
                printMachineStatus(&machine, emuConf);
                JSONValue j = ["result": "done"];
                writeln(j);
                continue;

            case "load_elf":
            case "loadelf":
                if (command.args.length != 1) {
                    writeError("Please supply the path of the file to load", emuConf.jsonInterface);
                    continue;
                }

                try {
                    machine = new Machine(MachineConfig());
                    machine.loadElf(Elf.readFile(command.args[0]));
                    JSONValue j = ["result": "done"];
                    writeln(j);
                } catch (Exception e) {
                    writeError(to!string(e.message), emuConf.jsonInterface);
                }
                continue;

            case "output":
                JSONValue j = ["output": machine.getOutput()];
                writeln(j);
                continue;

            case "loadasm":
            case "load_asm":
                if (command.args.length != 1) {
                    writeError("Please supply the path of the file to load", emuConf.jsonInterface);
                    continue;
                }
                try {
                    machine = new Machine(MachineConfig());
                    machine.loadElf(Assembler.assembleFile(command.args[0]));
                    JSONValue j = ["result": "done"];
                    writeln(j);
                } catch (Exception e) {
                    writeError(to!string(e.message), emuConf.jsonInterface);
                }
                continue;

            case "step":
            case "next":

                auto numSteps = command.args.length
                    ? to!uint(command.args[0])
                    : 1;

                foreach (i; 0..numSteps) {
                    auto insnLocation = machine.pc() - 8;
                    auto insn = Instruction.parse(insnLocation,
                            machine.getMemory(insnLocation, 4));
                    insn.execute(&machine);
                }

                printMachineStatus(&machine, emuConf);
                JSONValue j = ["result": "done"];
                writeln(j);
                continue;

            case "decode":
                if (command.args.length != 2) {
                    writeError("Please supply the instruction (as hex) " ~
                            "and location", emuConf.jsonInterface);
                    continue;
                }

                if (command.args[1].length != 8) {
                    writeError("Instruction should be 4 bytes hexadecimal",
                            emuConf.jsonInterface);
                    continue;
                }

                uint location = command.args[0].to!uint;
                uint insnBytes = command.args[1].to!uint(16);
                ubyte[] UbInsnBytes = (*cast(ubyte[4]*)&insnBytes);
                UbInsnBytes = UbInsnBytes.reverse; // Little endian :)

                try {
                    auto decoded = Instruction.parse(location, UbInsnBytes).toString();
                    JSONValue j = ["instruction": command.args[1], "disasm": decoded];
                    writeln(j);
                } catch (Exception e) {
                    JSONValue j = ["instruction": command.args[1], "disasm": "unknown"];
                    writeln(j);
                }

                continue;
            default:
                writeln("Couldn't understand command: ", command.cmd);
        }
    }
}

void printMachineStatus(Machine* machine, EmulatorConfig emuConf) {
    auto insnLocation = machine.pc() - 8;
    auto insn = Instruction.parse(insnLocation,
            machine.getMemory(insnLocation, 4));

    if (!emuConf.jsonInterface) {
        writeln("0x", format!("%04x\t")(insnLocation), insn);
        writeln("Current machine hash: ", machine.toHash());
    }
}

void printHelpAndExit() {
    writeln("help info goes here...");
    exit(1);
}

