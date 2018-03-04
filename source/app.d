import std.conv;
import std.getopt;
import std.stdio;
import std.string;
import std.json;

import machine;
import instruction;
import elfParser;

struct EmulatorConfig {
    bool jsonInterface;
    string filename;
}

struct EmulatorCommand {
    string cmd;
    string[] args;
}

void main(string[] args)
{
    EmulatorConfig emuConf;
    MachineConfig machineConf;

    auto helpInfo = getopt(
            args,
            "json", &emuConf.jsonInterface,
            "file", &emuConf.filename);

    Machine machine = emuConf.filename
        ? ElfParser.parseElf(emuConf.filename, machineConf)
        : new Machine(machineConf);

    // Set output to line buffering for json output
    if (emuConf.jsonInterface) {
        stdout.setvbuf(0, 2);
    }

    runLoop(machine, emuConf);
}

// Parse a command agnostically to input syntax.
// load_elf a.out
// { "cmd": "load_elf", "args": ["a.out"] }
EmulatorCommand parseCommand(string command, bool json) {
    EmulatorCommand parsedCommand;
    if (json) {
        auto j = parseJSON(command);
        parsedCommand.cmd = j["cmd"].str;
        foreach(JSONValue a; j["args"].array) {
            if (a.type() == JSON_TYPE.STRING) {
                parsedCommand.args ~= a.str;
            } else {
                parsedCommand.args ~= to!string(a.integer);
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

void writeError(string errorMessage, bool json) {
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

    if (!emuConf.jsonInterface)
        printMachineStatus(&machine, emuConf);

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
                    "machine_hash": machine.toHash()
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
                uint memLength = command.args.length > 2
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
                    import std.digest.digest;
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
                continue;

            case "step":
            case "next":
                auto insnLocation = machine.pc() - 8;
                auto insn = Instruction.parse(insnLocation,
                        machine.getMemory(insnLocation, 4));
                insn.execute(&machine);
                printMachineStatus(&machine, emuConf);
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

