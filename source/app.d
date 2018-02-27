import std.conv;
import std.getopt;
import std.stdio;
import std.string;

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
            cmd = ["next"];
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
            case "reg":
            case "registers":
                for (int i=0; i<16; i++) {
                    write(format!"%08x%s"(machine.getRegister(i), (i + 1)%8 ? "  " : "\n"));
                }
                continue;
            case "mem":
            case "memory":
                if (cmd.length == 1) {
                    writeln("usage: mem start_loc, length");
                    continue;
                }

                uint startLoc = to!uint(cmd[1]) & 0xfffffff3;

                uint memLength = cmd.length > 2 ? to!int(cmd[2]) : 64;
                ubyte[] mem = machine.getMemory(startLoc, memLength);

                import std.digest.digest;
                foreach(i; 0..(mem.length / 4)) {
                    write("0x");
                    write(format!("%04x")(i*4));
                    writeln("  0x", toHexString!(LetterCase.lower)(mem[i*4..(i+1)*4]));
                }

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
    auto insn = Instruction.parse(machine.pc() - 8, machine.getMemory(machine.pc()-8, 4));
    writeln(insn);
}

