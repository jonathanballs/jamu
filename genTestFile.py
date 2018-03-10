#!/usr/bin/python3
# Generates assembly code for fuzzy testing the assembler. Tests against
# the original arm assembly (of OG komodo fame). This is about ensuring
# that *valid* assembly is compiled correctly. Checks for invalid code
# will be carried out through more conventional unittests

import random
import os
import subprocess
from elftools.elf.elffile import ELFFile
from keystone import *

NUM_INS_PER_TEST = 100
TEST_DIR = 'test/tmp'
CONDITIONS = [
        'eq', 'ne', 'cs', 'cc',
        'mi', 'pl', 'vs', 'vc',
        'hi', 'ls', 'ge', 'lt',
        'gt', 'le', 'al', '']

# SETUP
if not os.path.exists(TEST_DIR):
    os.mkdir(TEST_DIR)


def test_code(test_name, source):
    print(test_name + "...", end='', flush=True)

    test_name = test_name.replace(" ", "_")

    input_filename = os.path.join(TEST_DIR, test_name + '.s')
    jasm_output_filename = os.path.join(TEST_DIR, test_name + '.out.jasm')
    kasm_output_filename = os.path.join(TEST_DIR, test_name + '.out.kasm')

    with open(input_filename, 'w+') as f:
        f.write(source)

    # Initialise keystone disasm
    ks = Ks(KS_ARCH_ARM, KS_MODE_ARM)

    jasm_command = "./jasm " + input_filename + " --output " + jasm_output_filename
    j = subprocess.run(jasm_command.split(' '), stdout=subprocess.PIPE)

    if j.returncode != 0:
        print(" ✗ JASM returned non zero: ", j.returncode)
        print(j.stdout)

    def getSegmentBytes(filename):
        with open(filename, 'rb') as f:
            elf = ELFFile(f)
            return elf.get_segment(0).data()

    j_bytes = getSegmentBytes(jasm_output_filename).hex()
    k_bytes = bytes(ks.asm(str.encode(source))[0]).hex()

    if j_bytes != k_bytes:
        print(" \033[91m✗\033[0m")
        # Split into chunks and find first bad one
        jsp = [ j_bytes[i:i+8] for i in range(0, len(j_bytes), 8) ]
        ksp = [ k_bytes[i:i+8] for i in range(0, len(k_bytes), 8) ]
        ssp = source.split('\n')

        for i in range(len(ssp)):
            if jsp[i] != ksp[i]:
                print("    '" + ssp[i] + "'", "is", jsp[i], "not", ksp[i])
                return
    else:
        print(" \033[92m✔\033[0m")


#
#
# BRANCHING
#
#
source = ""
for i in range(NUM_INS_PER_TEST):
    source += "B {}\n".format(i<<2)
test_code("Basic branching", source)
source = ""
for i in range(NUM_INS_PER_TEST):
    source += "B{} {}\n".format(CONDITIONS[i% 16], i<<2);
test_code("Conditional branching", source)

source = ""
for i in range(NUM_INS_PER_TEST):
    source += "BL {}\n".format(i<<2)
test_code("Basic branching and linking", source)
source = ""
for i in range(NUM_INS_PER_TEST):
    source += "BL{} {}\n".format(CONDITIONS[i%16], i<<2)
test_code("Conditional branching and linking", source)

source = ""
for i in range(NUM_INS_PER_TEST):
    ins = "BX R{}\n".format(i%16)
    source += ins
test_code("Basic branch and exchanging", source)
for i in range(NUM_INS_PER_TEST):
    ins = "BX{} R{}\n".format(CONDITIONS[i%16], str(i%16))
    source += ins
test_code("Conditional branch and exchanging", source)

