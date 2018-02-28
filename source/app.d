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
    printMachineStatus(&machine);

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

        // These commands are just for development for now. Time will be spent
        // trying to make them more intuitive
        switch(cmd[0]) {
            case "exit":
            case "quit":
                return;
            case "info":
                writeln("Machine info");
                writeln("Memory size:        ", machine.config.memorySize);
                writeln("Program counter:    ", machine.pc());
                continue;

            case "pc":
                cmd = ["reg", "15"];
            goto case;

            case "reg":
            case "registers":
                if (cmd.length == 1) {
                    for (int i=0; i<16; i++) {
                        write(format!"%08x%s"(machine.getRegister(i), (i + 1)%8 ? "  " : "\n"));
                    }
                } else {
                    try {
                        auto regNum = to!uint(cmd[1]);
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
                if (cmd.length == 1) {
                    writeln("usage: mem start_loc, length");
                    continue;
                }

                uint startLoc = to!uint(cmd[1]) & 0xfffffff3;

                uint memLength = cmd.length > 2 ? to!int(cmd[2]) : 64;
                ubyte[] mem = machine.getMemory(startLoc, memLength);

                import std.digest.digest;
                foreach(i; 0..(mem.length / 4)) {
                    write("0x", format!("%04x")(i*4));
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
    writeln("next instruction: ");
    auto insnLocation = machine.pc() - 8;
    auto insn = Instruction.parse(insnLocation,
            machine.getMemory(insnLocation, 4));

    write("0x", format!("%04x\t")(insnLocation));
    writeln(insn);
}

