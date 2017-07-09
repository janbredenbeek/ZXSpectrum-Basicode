; BASICODE-3 v3.1 FOR THE ZX SPECTRUM 48K
; COPYRIGHT (C) 1985-1987 BY JAN BREDENBEEK
; RELEASED UNDER GNU v3 PUBLIC LICENSE, 2017

; FUNCTIONS FOR BASICode EXTension
; REVISION 1.0: 10 DECEMBER 1985
; REVISION 3.1: 24 NOVEMBER 1987

       ORG    58840
	   
; Entry points for functions from BASIC
	   
       JP     LEFT$           ; LEFT$
       JP     MID$            ; MID$
       JP     RIGHT$          ; RIGHT$
       JP     VAL             ; VAL
       JP     SCREEN$         ; SCREEN$
       JP     SHIFT$          ; SHIFT$
       JP     EOF             ; EOF
       JP     VALSUB          ; VAL subroutine
       JP     VALFRC          ; VAL fractions

CHARS  EQU    58072		; pointer to character set (6-bit)

; Stack arguments for FN LEFT$, MID$, RIGHT$

STK_ARG
       LD     HL,(23563)      ; DEFADD holds addr of arguments area
       INC    HL              ; (like VARS area, but local to FN)
       INC    HL              ; point to string argument
       CALL   #33B4           ; stack string parameter
       INC    HL
       INC    HL              ; point to first numeric argument
STK_A1 CALL   #33B4           ; stack this one too
       CALL   #1E99           ; FIND-INT2
       PUSH   BC              ; save value
       CALL   #2BF1           ; STK-FETCH
       
; At this point DE points to the address of the string argument and BC holds
; its length (see explanation in BEXT.TXT). The numeric argument is now tested
; against the string length and adjusted if necessary (it cannot be greater)
       
       LD     H,B             ; String length to HL
       LD     L,C
       POP    BC              ; Get N
       AND    A
       SBC    HL,BC
       ADD    HL,BC           ; test if N>=LEN(A$)
       EX     DE,HL           ; length to DE, pointer to HL
       RET    NC              ; return if N<=LEN(A$)
       LD     B,D             ; else, adjust N
       LD     C,E
       RET

; LEFT$, MID$ and RIGHT$ enter here. They are called as user-defined (FN) 
; functions from BASIC, pointing to USR addresses (we'll tweak the type of
; the returned value to string before returning).
; Note that FN MID$ can have two or three arguments: MID$(A$,N) returns
; the equivalent of A$(N TO) and MID$(A$,N,M) returns A$(N TO N+M-1).
; The BEXT interpreter was changed in v3 to allow for a 'missing parameter' by
; putting all FFs in the 5 variable locations of the 'missing' argument, so
; we can pick this up here.
       
LEFT$  CALL   STK_ARG         ; LEFT$; get parameters and jump to store result
       JR     STK_STO

MID$   CALL   STK_ARG         ; MID$; get A$ and N first
       JR     NC,NOTEMPTY     ; if N<LEN(A$)
       LD     BC,#0000        ; else, string will be empty so adjust BC
       JR     STK_STO         ; ... and stack it
NOTEMPTY
       DEC    HL
       ADD    HL,BC           ; point to first char of substring
       EX     DE,HL           ; HL now holds LEN(A$), DE=pointer
       INC    HL
       LD     A,B             ; N may not be zero
       OR     C
       JP     Z,#2A20         ; else, error "Subscript wrong"
       SBC    HL,BC           ; now get length of substring
       LD     B,H             ; BC holds new length
       LD     C,L
       CALL   #2AB6           ; now stack the result string
       
; We still need to consider the form MID$(A$,N,M) 
       
       LD     HL,(23563)      ; DEFADD
       LD     BC,16
       ADD    HL,BC           ; point to location where M is stored
       LD     A,(HL)
       INC    A               ; if M is not given, A holds $FF
       JR     NZ,MID$_2       ; jump if M is present
       LD     DE,#FFFF        ; else, signal 'whole substring'
       CALL   #2D8C           ; and store dummy length
MID$_2 CALL   STK_A1          ; now stack M (or dummy '65535')
       JR     STK_STO         ; jump to store substring

; RIGHT$(A$,N) returns the rightmost N chars of A$ (ie A$(LEN(A$)-N+1 TO))
       
RIGHT$ CALL   STK_ARG         ; get A$ and N
       ADD    HL,DE           ; point to 1 past string
       AND    A
       SBC    HL,BC           ; and go back N chars (N<=LEN(A$))
       
; All three functions eventually come here to store the result string.
; HL points to start of (sub)string, BC holds length.
       
STK_STO
       EX     DE,HL           ; pointer to DE
       CALL   #2AB2           ; STK-STO-$ stacks string result
       
; We now need to do some mangling since the string functions were called by USR
; and the expression evaluator expects a numeric result. First we drop
; the return address of STACK-BC (since we already have stacked our string) and
; then we modify the type of the stacked result (pushed on the machine stack 
; from the expression evaluator) from 'numeric' to 'string'.
       
       POP    BC              ; drop address of STACK-BC
       LD     HL,4
       ADD    HL,SP           ; skipover return addresses from calculator
       RES    7,(HL)          ; this signals 'string result' when DE gets
                              ; popped from the stack at $2764
       JP     #35BF           ; exit via STACK-PNTRS 

; FN SHIFT$(A$) converts a string to uppercase       
       
SHIFT$ LD     HL,(23563)      ; DEFADD
       XOR    A
       CPIR                   ; look for end of parameter name (null byte)
       CALL   #33B4           ; stack string parameter
       CALL   #2BF1           ; STK-FETCH
       PUSH   BC              ; save length
       PUSH   DE              ; and pointer
       INC    BC              ; add extra byte (in case length is 0)
       RST    #30             ; and allocate this in WORKSP
       POP    HL              ; get pointer to source
       PUSH   DE              ; save pointer to destination
       LDIR                   ; and copy over the string
       POP    DE              ; restore destination
       POP    BC              ; original length
       PUSH   BC
       PUSH   DE
       
; now copy over the string, converting to uppercase as we go       
       
SH_LP  LD     A,B
       OR     C
       JR     Z,SH_END
       LD     A,(DE)
       CP     #60
       JR     C,SH_NXT
       CP     #80
       JR     NC,SH_NXT
       AND    #DF             ; note: braces, tilde etc get also converted!
       LD     (DE),A
SH_NXT INC    DE
       DEC    BC
       JR     SH_LP           ; loop while BC<>0
SH_END POP    HL              ; get destination pointer
       POP    BC              ; and length
       JR     STK_STO         ; and store result

; This is called by the expression evaluator (via jump vector) for the VAL
; function. This evaluates the string argument, which must represent a valid
; number. Thus it's not as sophisticated as the Spectrum's original VAL 
; function, which allowed complete expressions to be evaluated. However, in
; BASICODE, this is not part of the spec and even undesirable as it may lead
; to stopping the program with "Nonsense in BASIC" when trying to evaluate 
; something like VAL ("2abc"). In BASICODE, it is defined to return zero when
; the argument does not represent a valid number (sorry fans - after all it
; was designed around M$ Basic...)
       
VAL    CALL   #2BF1           ; STK-FETCH
       INC    BC
       PUSH   DE
       RST    #30             ; allocate len+1 in WORKSP
       POP    HL
       PUSH   DE
       LDIR                   ; and copy over
       EX     DE,HL
       DEC    HL
       LD     (HL),#0D        ; and padd with CR byte
       LD     HL,(23645)      ; get CH-ADD
       EX     (SP),HL         ; and swap with string address
       LD     (23645),HL
       CALL   VALSUB          ; now do actual operation
       POP    HL
       LD     (23645),HL      ; restore original CH-ADD
       RET
       
; This subroutine does the actual VAL operation
       
VALSUB RST    #28             ; invoke calculator
       DEFB   #A1;STK_ONE
       DEFB   #C2;ST_MEM_2
       DEFB   #02;DELETE
       DEFB   #38;END_CALC    ; MEM-2 now preset to 1
       RST    #18             ; get current char
       CP     "+"
       JR     Z,S_DONE        ; skipover '+'
       CP     "-"             
       JR     NZ,V_DEC
       DEC    (IY+100)        ; if '-', set MEM-2 to 0
S_DONE RST    #20             ; get next char
V_DEC  CALL   #2D3B           ; read integer part
VALFRC CP     "."             ; decimal point?
       JR     NZ,E_FORMAT     ; no, look for E-format
DEC_STO                       ; else, preload MEM-0 with 1
       RST    #28
       DEFB   #A1;STK_ONE
       DEFB   #C0;ST_MEM_0
       DEFB   #02;DELETE
       DEFB   #38;END_CALC
NXTDGT CALL   #0074           ; loop for fractional digits
       CALL   #2D22           ; stack new digit (if any)
       JR     C,E_FORMAT      ; until non-digit found
       RST    #28
       DEFB   #E0;GET_MEM_0
       DEFB   #A4;STK_TEN
       DEFB   #05;DIVISION
       DEFB   #C0;ST_MEM_0    ; 1 in MEM-0 goes to 0.1, 0.01 etc for each turn
       DEFB   #04;MULTIPLY    ; and multiply this by value of new digit
       DEFB   #0F;ADDITION    ; and add to running value
       DEFB   #38;END_CALC
       JR     NXTDGT
E_FORMAT                      ; consider xx.yyEzz format
       CP     "e"
       JR     Z,S_FLAG
       CP     "E"
       JR     NZ,VAL_END      ; if neither e or E we are finished
S_FLAG LD     B,#FF           ; preset B to $FF
       CALL   #0074
       CP     "+"
       JR     Z,SIGN_DONE
       CP     "-"             ; is exponent negative?
       JR     NZ,ST_E
       INC    B               ; yes, set B to 0
SIGN_DONE
       CALL   #0074           ; and skipover '+' or '-' after E
ST_E   PUSH   BC
       CALL   #2D3B           ; INT-TO-FP
       CALL   #2DD5           ; FP-TO-A
       POP    BC              ; restore BC
       JP     C,#31AD         ; overflow if exponent > 255
       AND    A
       JP     M,#31AD         ; and if >127 (in practice, anything above about
                              ; 38 will overflow later)
       INC    B               ; test sign, -1 for positive, 0 for negative
       JR     Z,E_CALC
       NEG                    ; if sign negative, negate A
E_CALC CALL   #2D4F           ; call E-TO-FP to calculate value in E-format
VAL_END                       ; almost finished, but finally look at sign
       RST    #28
       DEFB   #E2;GET_MEM_2   ; ... which is stored in MEM-2
       DEFB   #00;JUMP_TRUE   ; if positive, it will be 1
       DEFB   #02
       DEFB   #1B;NEGATE      ; else, negate result
       DEFB   #38;END_CALC    ; finished
       RET
       
; This is called by the SCREEN$ function. Since our BASICODE characters are
; only 6 bits wide to make 42 columns on the screen possible, we also have to
; write our own modified SCREEN$ to recognise the narrower characters...
; (it's called by GOSUB 220 from the standard subroutines)
       
SCREEN$
       CALL   #2307           ; STK-TO-BC
       LD     A,D
       OR     E
       AND    #80             ; one or both arguments negative?
       JR     NZ,SCR_EMPTY    ; yes, return empty string
       LD     A,B             ; B holds column number
       CP     42              ; .. which must be 0 to 41
       JR     NC,SCR_EMPTY
       LD     A,C             ; C holds row number
       CP     24              ; .. which must be 0 to 23
       JR     NC,SCR_EMPTY
       RRCA                   ; divide row by 8
       RRCA
       RRCA
       AND    #E0
       LD     L,A             ; L = 32 * (row MOD 8) (1)
       LD     A,C
       AND    #18
       OR     #40
       LD     H,A             ; H = 64 + 8 * (row DIV 8)
       LD     A,B
       ADD    A,A
       ADD    A,B
       LD     B,A             ; B = column * 3
       RRA
       SRL    A               ; A = (column * 3) DIV 4 (2)
       OR     L
       LD     L,A             ; Now L = (1) + (2), the low address byte
       LD     A,B
       ADD    A,A
       AND    #07
       INC    A               ; A = (column * 6) MOD 8 + 1
       LD     (23655),A       ; store in BREG as shift counter for SC_MATCH
       LD     DE,CHARS        ; pointer to our own charset (not the Spectrum's)
       LD     B,#60           ; loop for at most 96 characters
       
; Now enter a loop to find a matching character
; B = counter (from 96 to 1)
; DE = pointer to current entry in character set bitmap
; HL = current address in display file
       
SCR_LP PUSH   BC
       PUSH   HL
       PUSH   DE
       CALL   SC_MATCH        ; Match bitmap against character line
       JR     Z,MATCH         ; if match, loop for another 7 lines
       CP     #FC
       JR     NZ,SC_NXT       ; also consider case of INVERSE 1
MATCH  LD     C,A             ; save result (either 0 or $FC)
       LD     B,7             ; look for another 7 lines
SC_ROW INC    H               ; next display line is 256 bytes away
       INC    E               ; but next line in character set only 1
       CALL   SC_MATCH        ; now match them up
       XOR    C               ; and include mask from first line
       JR     NZ,SC_NXT       ; no match, next one
       DJNZ   SC_ROWS         ; loop for 7 lines
       POP    BC              ; we've found one!
       POP    BC
       POP    BC              ; B = original counter
       LD     A,#80
       SUB    B               ; form ASCII code in A
       LD     BC,#0001
       RST    #30
       LD     (DE),A          ; store 1 character in WORKSP
       RET                    ; finished
SC_NXT POP    DE              ; no match, get original char pointer
       LD     HL,#0008
       ADD    HL,DE
       EX     DE,HL           ; bump DE by 8
       POP    HL              ; original screen address
       POP    BC              ; original counter in B
       DJNZ   SCR_LP          ; loop for 96 characters
SCR_EMPTY
       LD     BC,#0000        ; no luck, return empty string
       RET
       
; This subroutine tries the actual match. The 6 bits found at the display
; position are picked up, rotated if needed and matched against the bitmap
; from the character set.
; Note that in our 42 column display it is possible for one character to 
; occupy 2 display locations (4 columns occupy exactly 3 locations), unlike
; the Spectrum's normal 32 column display where 1 character is exactly 1 byte.
; Hence, some bit munging is necessary to get the bits into the right place.
; The number of shifts needed + 1 is already stored in the BREG variable.
       
SC_MATCH
       PUSH   HL              ; save screen address
       LD     A,(HL)
       INC    HL
       LD     L,(HL)
       LD     H,A             ; get 2 screen bytes in HL
       LD     A,(23655)       ; get number of shifts + 1
SC_M_L DEC    A               ; count number of shifts
       JR     Z,SC_XOR        ; done
       ADD    HL,HL           ; else, shift bits left
       JR     SC_M_LP         ; and loop back
SC_XOR LD     A,(DE)          ; now match against character bitmap
       XOR    H               ; (only 6 msb's of HL)
       POP    HL              ; restore screen address
       AND    #FC             ; mask off unwanted bits
       RET

; FN EOF(channel) returns EOF status of an opened channel
; This is done by reading a byte from the channel and trapping the EOF error
; unfortunately, any character successfully read now has to be 'pushed back'
; into the stream and this is done by temporarily saving this character in a
; table and changing the address of the input routine to code which will return
; this character on the next call (and then restore the original pointer).
       
EOF    LD     HL,(23563)      ; get DEFADD
       XOR    A
       CPIR                   ; find start of argument value
       CALL   #33B4           ; store on calculator stack
       CALL   #1E94           ; fetch this into A
       CP     #10             
       JP     NC,#1725        ; 'invalid stream' if 16 or higher
       
; A table located at address $FF01 holds EOF status information for each
; stream. Each entry has 4 bytes:
; byte 0: status; 0 = unused; $FF = input pending
; byte 1: character to return on next input call
; byte 2 and 3: address of original input routine       
       
       LD     L,A
       ADD    HL,HL
       ADD    HL,HL           ; multiply stream # by 4
       INC    L
       LD     H,#FF           ; form table entry address in HL
       LD     BC,0            ; preset BC to 0 for 'no EOF'
       BIT    7,(HL)          ; test 'used' flag
       RET    NZ              ; return 'no EOF' when input is pending
       PUSH   HL              ; save table address
       LD     HL,(23633)
       PUSH   HL              ; save CURCHL pointer
       CALL   #1601           ; select this stream
       EXX                    ; go to alternate register set
       
; this code changes the error stack pointer to IN_RET below and tries to fetch
; a character from the selected channel. After restoring the original ERR_SP,
; the error return is tested for EOF.
       
       PUSH   HL              ; save original HL
       LD     HL,(23613)
       PUSH   HL              ; save original ERR_SP
       LD     HL,IN_RET
       PUSH   HL
       LD     (23613),SP      ; make IN_RET the error return point
       CALL   #15DE           ; now call INPUT_AD1 to fetch a character
       POP    HL              ; No error - drop IN_RET address
IN_RET POP    HL              ; any error returns here
       LD     (23613),HL      ; restore original ERR_SP
       POP    HL              ; original HL
       EXX                    ; restore original register set
       LD     HL,(23633)      ; CURCHL
       EX     (SP),HL
       LD     B,A             ; save character read
       CALL   #1615           ; reset CURCHL to original value
       POP    DE              ; get pointer to channel where we've read from
       POP    HL              ; table entry address
       LD     A,(23610)
       INC    A               ; test error code
       JR     Z,NO_EOF        ; no error so we have to save character read
       CP     #08
       JP     NZ,#0058        ; if error was other than EOF, report it
       LD     (IY+0),#FF      ; else, reset EOF error
       LD     BC,1            ; and return 1 for EOF
       RET
       
; A character has been read from the input, but it has to be pushed back into
; the input stream. This is done by saving it into the table and temporarily
; changing the input routine's address to our own routine which returns it
; on the next input call.       
       
NO_EOF LD     (HL),#FF        ; flag 'input pending'
       INC    HL
       LD     (HL),B          ; store character to be returned
       INC    HL
       EX     DE,HL           ; HL points to channel info
       INC    HL
       INC    HL              ; step past output routine pointer
       LDI                    
       LDI                    ; copy input routine pointer to table entry
       LD     DE,NEWINP       ; our temporary input routine
       DEC    HL
       LD     (HL),D
       DEC    HL
       LD     (HL),E          ; enter this into the channel's input routine ptr
       LD     BC,0            ; no EOF
       RET
       
; A temporary input routine is used to return the character read from the call
; to FN EOF(). After this, the address of the original input routine is
; restored.
       
NEWINP LD     HL,(23633)      ; CURCHL
       LD     DE,(23631)      ; CHANS
       XOR    A
       SBC    HL,DE
       LD     B,H
       LD     C,L
       INC    BC              ; BC = offset of channel from CHANS + 1
       LD     HL,#5C16        ; STRMS
EOF_LP LD     E,(HL)          ; now we have to find the stream number attached
       INC    HL              ; to our channel
       LD     D,(HL)
       INC    HL
       EX     DE,HL
       AND    A
       SBC    HL,BC           ; offset in STRMS matches our channel?
       JR     Z,EOFFND        ; yes, look for pending input
       EX     DE,HL
       INC    A
       CP     #10
       JR     C,EOF_LP        ; loop for streams 0 to 15
       AND    A               ; if not found, return C and Z reset ('no input')
       RET
EOFFND RLCA                   
       RLCA
       INC    A
       LD     L,A
       LD     H,#FF           ; find table entry
       LD     DE,(23633)      ; CURCHL
       INC    DE
       INC    DE              ; step past output routine pointer
       LD     (HL),0          ; flag 'no pending input'
       INC    HL
       LD     A,(HL)          ; and fetch character to be returned
       INC    HL              ; point to original routine pointer
       LDI                    
       LDI                    ; copy this to channel pointer
       SCF                    ; signal 'succesful read'
       RET
