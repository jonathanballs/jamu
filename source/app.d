import std.stdio;
import std.getopt;

import machine;
import elfParser;

void main(string[] args)
{
    auto filename = args.length == 2 ? args[1] : "a.out";
    MachineConfig config;

    auto machine = ElfParser.parseElf(filename, config);
}

