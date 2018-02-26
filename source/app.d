import std.stdio;
import std.string;
import std.getopt;

import machine;
import instruction;
import elfParser;

void main(string[] args)
{
    auto filename = args.length == 2 ? args[1] : "a.out";
    MachineConfig config;

    auto machine = ElfParser.parseElf(filename, config);

    runLoop(machine);
}

void runLoop(Machine machine) {
    string prompt = ">>> ";

    while (true) {
        // Write the prompt
        import colorize : fg, color, cwrite;
        cwrite(prompt.color(fg.green));

        auto l = readln().chomp();

        auto cmd = l.split(" ");

        if (cmd.length == 0) {
            continue;
        }

        switch(cmd[0]) {
            case "exit":
            case "quit":
                return;
            case "info":
                writeln("Machine info");
                writeln("Memory size:        ", machine.config.memorySize);
                writeln("Program counter:    ", machine.pc());
                continue;
            case "step":
            case "next":
                auto insnBytes = Instruction.parse(machine.pc() - 8, machine.getMemory(machine.pc()-8, 4));
                writeln(insnBytes);
                continue;
            default:
                writeln("Couldn't understand command");
        }
    }
}

void printMachineStatus(Machine machine) {
}

