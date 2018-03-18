# jasm
This is an assembler for ARMv4 instruction set. It is intended for students to use and emphasizes ease of use and clarity of error messages over effiency and number of features. To build just run `dub` and to assemble a file run `jasm <filename> --output <filename>`

The executable will be written to `a.out` if `--output` is not specified.

List of instructions supported:

- [X] ADC
- [X] ADD
- [X] AND
- [X] B
- [X] BIC
- [X] BL
- [X] BX
- [ ] CDP
- [X] CMN
- [X] CMP
- [X] EOR
- [ ] LDC
- [ ] LDM
- [X] LDR
- [ ] MCR
- [ ] MLA
- [X] MOV
- [ ] MRC
- [ ] MRS
- [ ] MSR
- [ ] MUL
- [X] MVN
- [X] ORR
- [X] RSB
- [X] RSC
- [X] SBC
- [ ] STC
- [ ] STM
- [X] STR
- [X] SUB
- [X] SWI
- [ ] SWP
- [X] TST

