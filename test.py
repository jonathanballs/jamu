#!/usr/bin/python3
# Generates assembly code for fuzzy testing the assembler. Tests against
# the original arm assembly (of OG komodo fame). This is about ensuring
# that *valid* assembly is compiled correctly. Checks for invalid code
# will be carried out through more conventional unittests
# (C) Jonathan Balls

import random
import os
import subprocess
from keystone import *
from elftools.elf.elffile import ELFFile

TOTAL_INS_TESTED = 0
NUM_INS_PER_TEST = 256
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

    global TOTAL_INS_TESTED
    TOTAL_INS_TESTED += len(source.split('\n'))

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
        print(" \033[91m✗\033[0m JASM returned non zero: ", j.returncode)
        out = j.stdout.decode().split('\n')
        for l in out[1:6]:
            print(l)
        if len(out) > 5:
            print("and {} other errors...".format((len(out) // 6) - 1))
        return

    def getSegmentBytes(filename):
        with open(filename, 'rb') as f:
            elf = ELFFile(f)
            return elf.get_segment(0).data()

    j_bytes = getSegmentBytes(jasm_output_filename).hex()
    k_bytes = None
    try:
        k_bytes = bytes(ks.asm(str.encode(source), addr=0)[0]).hex()
    except KsError as e:
        print(" \033[91m✗\033[0m Keystone failed to compile ({})".format(
            e.message
            ))
        return

    if j_bytes != k_bytes:
        print(" \033[91m✗\033[0m")
        # Split into chunks and find first bad one
        jsp = [ j_bytes[i:i+8] for i in range(0, len(j_bytes), 8) ]
        ksp = [ k_bytes[i:i+8] for i in range(0, len(k_bytes), 8) ]
        ssp = source.split('\n')

        for i in range(len(ssp)):
            if jsp[i] != ksp[i]:
                print("    '" + ssp[i] + "'", "incorrectly compiles to", jsp[i], "instead of", ksp[i])
                return
    else:
        print(" \033[92m✔\033[0m")

#
#
# BRANCHING
# Tests the B, BL and BX instructions
#
source = ""
for i in range(NUM_INS_PER_TEST):
    source += "B {}\n".format(i<<2)
for i in range(NUM_INS_PER_TEST):
    source += "B{} {}\n".format(CONDITIONS[i% 16], i<<2);
test_code("Testing b instruction", source)

source = ""
for i in range(NUM_INS_PER_TEST):
    source += "BL {}\n".format(i<<2)
for i in range(NUM_INS_PER_TEST):
    source += "BL{} {}\n".format(CONDITIONS[i%16], i<<2)
test_code("Testing bl instruction", source)

source = ""
for i in range(NUM_INS_PER_TEST):
    source += "BX R{}\n".format(i%16)
for i in range(NUM_INS_PER_TEST):
    source += "BX{} R{}\n".format(CONDITIONS[i%16], str(i%16))
test_code("Testing bx instruction", source)

#
#
# DATA PROCESSING INSTRUCTIONS
#
#
MATHEMATICAL_INSN = ['and', 'eor', 'sub', 'rsb', 'add', 'adc', 'sbc', 'rsc', 'orr', 'bic']
for insn in MATHEMATICAL_INSN:
    source = ''
    for i in range(NUM_INS_PER_TEST):
        source += "{} R{}, R{}, R{}\n".format(insn, i%16, i//16, (i+8)%16)
    for i in range(NUM_INS_PER_TEST):
        source += "{} R{}, R{}, #{}\n".format(insn, i%16, i//16, i)
    for i in range(NUM_INS_PER_TEST): # Conditions
        source += "{}{} R{}, R{}, #{}\n".format(insn, CONDITIONS[i%16], i%16, i//16, i)
    for i in range(NUM_INS_PER_TEST):
        source += "{}S{} R{}, R{}, R{}\n".format(insn, CONDITIONS[i%16], i%16, i//16, i%16)
    for i in range(NUM_INS_PER_TEST): # Set bit
        source += "{}S R{}, R{}, #{}\n".format(insn, i%16, i//16, i)
    for i in range(NUM_INS_PER_TEST):
        source += "{}S R{}, R{}, R{}\n".format(insn, i%16, i//16, i%16)
    test_code("Testing {} instruction".format(insn), source)


COMP_INSN = ['tst', 'teq', 'cmp', 'cmn']
for insn in COMP_INSN:
    source = ''
    for i in range(NUM_INS_PER_TEST):
        source += "{} R{}, R{}\n".format(insn, i%16, i//16)
    for i in range(NUM_INS_PER_TEST):
        source += "{} R{}, #{}\n".format(insn, i%16, i)
    for i in range(NUM_INS_PER_TEST):
        source += "{}{} R{}, R{}\n".format(insn, CONDITIONS[i%16], i%16, i//16)
    for i in range(NUM_INS_PER_TEST):
        source += "{}{} R{}, #{}\n".format(insn, CONDITIONS[i%16], i%16, i)
    test_code("Testing {} instruction".format(insn), source)


MOV_INSN = ['mov', 'mvn']
for insn in MOV_INSN:
    source = ''
    for i in range(NUM_INS_PER_TEST):
        source += "{} R{}, R{}\n".format(insn, i%16, i//16)
    for i in range(NUM_INS_PER_TEST):
        source += "{} R{}, #{}\n".format(insn, i%16, i)
    for i in range(NUM_INS_PER_TEST):
        source += "{}{} R{}, R{}\n".format(insn, CONDITIONS[i%16], i%16, i//16)
    for i in range(NUM_INS_PER_TEST):
        source += "{}{} R{}, #{}\n".format(insn, CONDITIONS[i%16], i%16, i)
    for i in range(NUM_INS_PER_TEST):
        source += "{}s{} R{}, R{}\n".format(insn, CONDITIONS[i%16], i%16, i//16)
    for i in range(NUM_INS_PER_TEST):
        source += "{}s{} R{}, #{}\n".format(insn, CONDITIONS[i%16], i%16, i)
    test_code("Testing {} instruction".format(insn), source)


#
#
# SOFTWARE INTERRUPTS
#
#

source = ''
for i in range(NUM_INS_PER_TEST):
    source += "SWI #{}\n".format(i)
for i in range(NUM_INS_PER_TEST):
    source += "SWI{} #{}\n".format(CONDITIONS[i%16], i)
test_code("Testing swi instruction", source)


#
#
# SINGLE STORE INSTRUCTIONS
#
#
SSTORE_INSN = ['ldr', 'str']
for insn in SSTORE_INSN:
    source = ''
    for i in range(NUM_INS_PER_TEST):
        source += "{} R{}, label\n".format(insn, i%16)
    for i in range(NUM_INS_PER_TEST):
        source += "{} R{}, label\n".format(insn, i%16)

    source += 'label:;'
    test_code("Testing {} instruction".format(insn), source)

print("Tested {} instructions".format(TOTAL_INS_TESTED))

