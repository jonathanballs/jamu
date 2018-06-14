        B main

        ALIGN
board   DEFW  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
boardMask
        DEFW -1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1
        ALIGN
seed    DEFW    0xC0FFEE
mult    DEFW    65539
mask    DEFW    0x7FFFFFFF
row     DEFW    64,0
top     DEFB "     1    2    3    4    5    6    7    8\n\n\0" 

prompt  DEFB "Enter square to reveal: ",0
remain  DEFB "There are ",0
remain2 DEFB " squares remaining.\n",0
already DEFB "That square has already been revealed...\n", 0
loseMsg DEFB "You stepped on a mine, you lose!\n",0
winMsg  DEFB "You successfully uncovered all the squares while avoiding all the mines...\n",0

        ALIGN
main    MOV R13, #0x10000
        ADR R0, board 
        MOV R5,#56
        BL generateBoard
mloop   BL clearScreen
        BL printMaskedBoard
        CMP R5,#0
        ADREQ R0,winMsg
        SWIEQ 3
        SWIEQ 2
        ADR R0, remain
        SWI 3
        MOV R0,R5
        SWI 4
        ADR R0, remain2
        SWI 3 
iagain  BL boardSquareInput
        MOV R2,R0
        ADR R3,boardMask
        LDR R1,[R3,R2 LSL #2] 
        CMP R1,#0
        ADREQ R0,already
        SWIEQ 3
        BEQ iagain
        SUB R5,R5,#1
        MOV R1,#0
        STR R1,[R3,R2 LSL #2] 
        ADR R3,board
        LDR R1,[R3,R2 LSL #2]
        CMP R1,#66
        BEQ lost
        B mloop

lost    ADR R0,loseMsg
        SWI 3
        SWI 2


clearScreen
        STMFD R13!,{R1-R7,R14}
        MOV R0,#8
        MOV R1,#700
clloop  SUBS R1,R1,#1
        SWI 0
        BNE clloop
        LDMFD R13!,{R1-R7,PC}

boardSquareInput
        ADR R0, prompt
        SWI 3
        MOV R1,#0  
        SWI 1  
        SWI 0
        CMP R0,#65
        BLT error
        CMP R0,#72
        BGT error
        SUB R0,R0,#65
        ADD R1,R1,R0 ASL #3
nmb     SWI 1  
        SWI 0
        CMP R0,#48
        BLE error
        CMP R0,#57
        BGE error
        SUB R0,R0,#49
        ADD R1,R1,R0
        B print

print   SWI 1
        CMP R0,#10
        BNE error
        SWI 0
        MOV R0,R1
        MOV PC,R14

error   MOV R0,#13
        SWI 0
        B boardSquareInput
        

printMaskedBoard
        printMaskedBoard
        ADRL R0, board 
        ADRL R1, boardMask
        MOV R3,R0
        MOV R2,R1
        ADR R0,top
        SWI 3

loopr   MOV R1,#1
        LDR R0,row
        ADD R0,R0,#1
        SWI 0 
        STR R0,row
        MOV R0,#32
        SWI 0
        SWI 0
        SWI 0

loopc   
        MOV R0,#32
        SWI 0
        LDR R0,[R2]
        CMP R0,#0
        BNE prtstr
        LDR R0,[R3]
        CMP R0,#0
        MOVEQ R0,#' '
        BEQ prt
        CMP R0,#66
        MOVEQ R0,#'M'
        BEQ prt
        ADD R0,R0,#48
prt     SWI 0
     
cnt     MOV R0,#32
        SWI 0
        SWI 0
        SWI 0
        ADD R3,R3,#4
        ADD R2,R2,#4
        ADD R1,R1,#1
        CMP R1,#8
        BLE loopc
        MOV R0,#10
        SWI 0
        SWI 0
        LDR R0,row
        CMP R0,#72
        MOVEQ R3,#64
        STREQ R3,row
        MOVEQ PC,R14
        B loopr

prtstr  MOV R0,#'*'
        SWI 0
        B cnt

generateBoard
        STMFD R13!,{R1-R7,R14}
        ADRL R0, board
        MOV R5,R0
        MOV R4,#0
        B randl
mset    B init1
end     LDMFD R13!,{R1-R7,PC}


randl   BL randu
        MOV R0,R0 ASR #8
        AND R0, R0, #0x3f
        MOV R2,R0 LSL #2
        LDR R1,[R5,R2]
        CMP R1,#0
        BNE randl
        ADD R4,R4,#1
        MOV R3,#66
        STR R3, [R5,R2]
        CMP R4,#7
        BLE randl
        B mset

init1   MOV R4,#0 
loop1   MOV R6,#0             
loop2   ADD R7,R6,R4 ASL #3
        LDR R0,[R5,R7] 
        CMP R4,#0
        SUBNE R1,R4,#4
        MOVEQ R1,R4
        CMP R0,#66
        BNE cond2   
loop3   CMP R6,#0
        SUBNE R2,R6,#4
        MOVEQ R2,R6
loop4   ADD R7,R2,R1 ASL #3
        LDR R0, [R5,R7]
        CMP R0,#66
        ADDNE R0,R0,#1
        STRNE R0,[R5,R7]
cond4   CMP R6,#28
        ADDNE R3,R6,#4
        MOVEQ R3,R6
        ADD R2,R2,#4
        CMP R2,R3
        BLE loop4
cond3   CMP R4,#28
        ADDNE R3, R4,#4
        MOVEQ R3,R4
        ADD R1,R1,#4
        CMP R1,R3
        BLE loop3        
cond2   CMP R6,#28 ;end of loop1
        ADD R6,R6,#4
        BLT loop2
cond1   CMP R4,#28 ;end of loop1
        ADD R4,R4,#4
        BLT loop1
        B end
randu   STMFD R13!,{R1-R7,R14}
        LDR R1,seed
        LDR R3,mult
        LDR R2,mask
        MUL R1,R1,R3
        AND R1,R1,R2
        MOV R0,R1
        STR R1,seed
        LDMFD R13!,{R1-R7,PC}