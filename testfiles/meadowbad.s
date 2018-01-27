; Program to print 'The Meadow Song'
; Username: psycjba
; Name: Charles Jonathan Balls
; Student ID: 4248614

	B main

verses 	DEFW	4
refrain DEFB	"Went to mow a meadow\n",0
wentmow	DEFB	"went to mow\n",0
men	DEFB	" men ",0
menc	DEFB	" men, ",0
man	DEFB	" man ",0
anddog	DEFB	" man and his dog, Spot\n",0

	ALIGN

main
	LDR R1, verses		; R1 will hold the current verse being written.
				; It will decrement at the end of each loop.
	
next	MOV R0, R1
	SWI 4{
	CMP R1, #1
	ADREQ R0, man
	ADRNE R0, men
	SWI 3
	ADR R0, wentmow
	SWI 3

	ADR R0, refrain		; Second line (refrain)
	SWI 3

	MOV R2, R1		; Third line (countdown of men)
cd_nman	MOV R0, R2
	SWI 4
	CMP R2, #1
	ADRNE R0, menc
	ADREQ R0, anddog
	SWI 3
	SUBS R2, R2, #1
	BNE cd_nman

	ADR R0, refrain		; Fourth line (refrain)
	SWI 3

	MOV R0, #10		; Print newline between verses
	SWI 0
	SUBS R1, R1, #1		; Decrement R1, go to next verse if not zero
	BNE next

	SWI 2
