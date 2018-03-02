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
            parsedCommand.args ~= a.str;
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

void runLoop(Machine machine, EmulatorConfig emuConf) {

    printMachineStatus(&machine);
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
            if (emuConf.jsonInterface) {
                JSONValue j = ["error": "Unable to parse json command"];
                writeln(j.toString);
            } else {
                writeln("Error: Unable to understand command");
            }
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
                writeln("Machine info");
                writeln("Memory size:        ", machine.config.memorySize);
                writeln("Program counter:    ", machine.pc());
                continue;

            case "pc":
                command.cmd = "reg";
                command.args = ["15"];
                goto case;

            case "reg":
            case "registers":
                if (!command.args.length) {
                    for (int i=0; i<16; i++) {
                        write(format!"%08x%s"(machine.getRegister(i), (i + 1)%8 ? "  " : "\n"));
                    }
                } else {
                    try {
                        auto regNum = to!uint(command.args[0]);
                        writeln(format!"%08x"(machine.getRegister(regNum)));
                    } catch (Exception e) {
                        writeln("Unknown register number");
                    }
                }
                continue;


            case "cpsr":
                auto cpsr = machine.getCpsr();
                writeln("neg: ", cpsr.negative, ", zero: ", cpsr.zero,
                        ", carry: ", cpsr.carry, ", overflow: ", cpsr.overflow);
                writeln("dIRQ: ", cpsr.disableIRQ, ", dFIQ: ", cpsr.disableFIQ,
                        ", state: ", cpsr.state, ", mode: ", cpsr.mode);
                continue;

            case "mem":
            case "memory":
                if (!command.args.length) {
                    writeln("usage: mem start_loc, length");
                    continue;
                }

                uint startLoc = to!uint(command.args[0]) & 0xfffffff3;

                uint memLength = command.args.length > 2
                    ? to!int(command.args[1])
                    : 64;

                ubyte[] mem = machine.getMemory(startLoc, memLength);

                import std.digest.digest;
                foreach(i; 0..(mem.length / 4)) {
                    write("0x", format!("%04x")(i*4));
                    writeln("  0x", toHexString!(LetterCase.lower)(mem[i*4..(i+1)*4]));
                }

                continue;
            
            case "back":
            case "prev":
                machine.stepBack();
                printMachineStatus(&machine);
                continue;

            case "step":
            case "next":
                auto insnLocation = machine.pc() - 8;
                auto insn = Instruction.parse(insnLocation,
                        machine.getMemory(insnLocation, 4));
                insn.execute(&machine);
                printMachineStatus(&machine);
                continue;
            default:
                writeln("Couldn't understand command");
        }
    }
}

void printMachineStatus(Machine* machine) {
    auto insnLocation = machine.pc() - 8;
    auto insn = Instruction.parse(insnLocation,
            machine.getMemory(insnLocation, 4));

    writeln("0x", format!("%04x\t")(insnLocation), insn);
    writeln("Current machine hash: ", machine.toHash());
}

