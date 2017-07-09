; BASICODE-3 v3.1 FOR THE ZX SPECTRUM 48K
; Copyright (C) 1985-2017 by JAN BREDENBEEK, HILVERSUM, THE NETHERLANDS
; RELEASED UNDER GNU v3 PUBLIC LICENSE, 2017

; BEXT SECTION 2
; v2.02; 24 NOVEMBER 1987

; Table containing token codes for modified commands

EXT_OF DEFB   #F3,P_NEXT-$
       DEFB   #FE,P_RETURN-$
       DEFB   #FA,P_IF-$
       DEFB   #EB,P_FOR-$
       DEFB   #EC,P_GOTO-$
       DEFB   #ED,P_GOSUB-$
       DEFB   #EA,P_REM-$
       DEFB   #F5,P_PRINT-$
       DEFB   #F6,P_PLOT-$
       DEFB   #FC,P_DRAW-$
       DEFB   #EE,P_INPUT-$
       DEFB   #E9,P_DIM-$
       DEFB   #F7,P_RUN-$
       DEFB   #F0,P_LIST-$
       DEFB   #E3,P_READ-$
       DEFB   #E5,P_RESTORE-$
       DEFB   #E0,P_LPRINT-$
       DEFB   #E1,P_LLIST-$
       DEFB   #D8,P_CIRCLE-$
       DEFB   #CE,P_DEFFN-$
       DEFB   #FD,P_CLEAR-$
       DEFB   #00

;SYNTAX TABLE FOR
;"EXTENDED" COMMANDS

P_IF   DEFB   #06,#CB,#05
       DEFW   IF
P_FOR  DEFB   #04,"=",#06
       DEFB   #CC,#06,#05
       DEFW   FOR
P_NEXT DEFB   #05
       DEFW   NEXT
P_GOTO
       DEFB   #05
       DEFW   GOTO
P_GOSUB
       DEFB   #05
       DEFW   GOSUB
P_RETURN
       DEFB   #00
       DEFW   RETURN
P_PRINT
       DEFB   #05
       DEFW   PRINT
P_INPUT
       DEFB   #05
       DEFW   INPUT
P_DIM  DEFB   #05
       DEFW   DIM
P_REM  DEFB   #05
       DEFW   REM
P_RUN  DEFB   #03
       DEFW   RUN
P_LIST DEFB   #05
       DEFW   LIST
P_READ DEFB   #05
       DEFW   READ
P_RESTORE
       DEFB   #03
       DEFW   RESTORE
P_LPRINT
       DEFB   #05
       DEFW   LPRINT
P_LLIST
       DEFB   #05
       DEFW   LLIST
P_CIRCLE
       DEFB   #09,#05
       DEFW   CIRCLE
P_PLOT DEFB   #09,#00
       DEFW   PLOT
P_DRAW DEFB   #09,#05
       DEFW   DRAW
P_DEFFN
       DEFB   #05
       DEFW   DEF_FN
P_CLEAR
       DEFB   #05
       DEFW   CLEAR
       
; Main statement loop       
       
STMT_LOOP
       RST    #20             ; get next char
ST_L_1 CALL   #16BF           ; clear workspace
       INC    (IY+13)         ; bump SUBPPC
       JP     M,#1C8A         ; but only 127 allowed on a line
       RST    #18
       LD     B,#00
       CP     #0D             ; already at end?
       JP     Z,LINE_END      ; yes
       CP     #3A             ; colon?
       JR     Z,STMT_LOOP     ; loop back
       LD     HL,STMT_RET     ; make STMT_RET the return address
       PUSH   HL
       LD     C,A             ; save command code
       RST    #20             ; advance BASIC pointer
       LD     HL,EXT_OF       ; first try our 'extended' command table
       CALL   #16DC           ; INDEXER
       JR     C,ST_L_2        ; jump if found
       LD     A,C             ; get command code again in A
       CP     "*"             ; BASICODE Menu command?
       JR     Z,BSC_CMD       ; yes
       CALL   RE_TEST         ; This tests for Interface-1 commands and sets
                              ; addresses for re-entry to the BEXT interpreter
       SUB    #CE             ; command code is now 00-31H
       JP     C,#1C8A         ; 'Nonsense in BASIC' if otherwise
       LD     C,A
       LD     HL,#1A48        ; Syntax offset table for standard Spectrum cmds
       ADD    HL,BC
ST_L_2 LD     C,(HL)          ; get offset
       ADD    HL,BC           ; now HL points to syntax table entry
       JR     GET_PA          ; GET-PARAM
SCAN_L LD     HL,(#5C74)      ; Loop back here for next syntax table entry
GET_PA LD     A,(HL)          ; get syntax table code
       INC    HL
       LD     (#5C74),HL      ; save pointer in T_ADDR
       LD     BC,SCAN_L
       PUSH   BC              ; return to SCAN_LOOP
       LD     C,A
       CP     #20             ; separator code?
       JP     NC,#1B6F        ; jump to SEPARATOR routine in ROM
       LD     HL,CL0          ; our command class table
       LD     B,#00
       ADD    HL,BC
       LD     C,(HL)          ; get offset
       ADD    HL,BC           ; and form address of handler
       PUSH   HL              
       RST    #18             ; get current character
       DEC    B               ; this sets B to FFH.
       RET                    ; jump indirect to command class handler

; Handle BASICODE menu command (starting with '*')       
       
BSC_CM LD     HL,(EXTVEC)     ; get ptr to menu
       LD     C,(HL)          ; get length in BC
       INC    HL
       LD     B,(HL)
       INC    HL
       LD     DE,#0000        ; checksum
CHKLOO LD     A,(HL)
       ADD    A,E
       LD     E,A
       JR     NC,DEC_CT
       INC    D
DEC_CT DEC    BC
       LD     A,B
       OR     C
       INC    HL
       JR     NZ,CHKLOOP      ; loop for checksum
       LD     A,(HL)
       DEC    A
       JR     NZ,RPRT_U       ; a byte 01 must follow
       INC    HL
       LD     C,(HL)
       INC    HL
       LD     B,(HL)
       INC    HL
       EX     DE,HL           ; address of menu handler to DE
       AND    A
       SBC    HL,BC           ; compare stored checksum to calculated
       PUSH   DE              ; stack menu handler as return address
       RET    Z               ; if checksums match, jump to it
RPRT_U CALL   ERROR           ; Report U: "Bad user routine"
       DEFB   #1D

; Return from executed BASIC statement       
       
STMT_RET
       SCF                    ; preset carry for 'no BREAK'
       LD     A,(BRKFLG)      ; flag is 1 BREAK has been disabled
       DEC    A               
       CALL   NZ,#1F54        ; test BREAK key unless BRKFLAG is 1
       JP     NC,#1B7B        ; carry is reset if BREAK pressed
       BIT    7,(IY+10)       ; test NSPPC (>=0 if jump to be made)
       JP     NZ,ST_NEXT      ; no jump, continue to next statement
       LD     HL,(23618)      ; else, get new line from NEWPPC
       BIT    7,H             ; jump unless direct command
       JR     Z,LN_NEW

; Run a direct command
       
PROG_RUN
       LD     HL,#FFFE
       LD     (23621),HL      ; set PPC to -2
       LD     HL,(23649)      ; WORKSP
       DEC    HL
       LD     DE,(23641)      ; E_LINE
       DEC    DE
       LD     A,(23620)       ; NSPPC
       JR     NEXT_LINE
       
; There has been a jump in the BASIC program; HL holds new line number
       
LN_NEW LD     DE,(23621)      ; PPC (current line number)

; Be smart: if the line number to be jumped to is higher than the current line
; then start searching from NXTLIN rather than PROG!

       SCF
       LD     B,H             ; copy new line number to BC
       LD     C,L
       SBC    HL,DE           ; is new line number > current?
       LD     HL,(23637)      ; pre-load NXTLIN pointer
       JR     NC,LN_FND       ; yes, start searching from there
       LD     HL,(23635)      ; if not, search from PROG base
       
; Now loop to find the new line (we don't use the slooow ROM routine)       
       
LN_FND LD     A,(HL)          ; MSB of line number
       CP     B               ; test against B
       JR     NC,LN_TST       ; if >=B, make further test on LSB
LN_T1  INC    HL
       INC    HL              ; we haven't made it yet, step past line number
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       INC    HL
       ADD    HL,DE           ; skip to next line
       JR     LN_FND          ; loop back
LN_TST JR     NZ,LN_T2        ; if MSB(current) > B, we're done
       INC    HL
       LD     A,(HL)          ; else, compare LSB against C
       DEC    HL              ; compensate INC above
       CP     C
       JR     C,LN_T1         ; loop if we're still not where we want to be
LN_T2  LD     A,(23620)       ; NSPPC
       JR     Z,LN_USE        ; jump if we're on the line we want
       AND    A               ; else, consider 'next line after'
       JP     NZ,#1BEC        ; NSPPC should be zero, else report N
       LD     B,A             ; save NSPPC in B
       LD     A,(HL)          ; get first byte of 'next line after'
       INC    A               ; NEW: a $FF byte marks 'end of program'
       LD     A,B             ; restore NSPPC
       JR     NZ,LN_USE       ; if end of program, stop with 'OK' report
       RST    8
       DEFB   #FF

; REM command; drop return address STMT_RET       
       
REM    POP    BC

; End of BASIC line reached

LINE_END
       LD     HL,(23637)      ; NXTLIN
       LD     A,(HL)          ; get first byte (MSB of line number)
       AND    A
       RET    M               ; if negative, end of program reached
       XOR    A               ; signal 'statement 0'.
LN_USE CP     #01
       ADC    A,#00           ; change statement 0 to 1
       LD     D,(HL)
       INC    HL
       LD     E,(HL)
       LD     (23621),DE      ; set PPC to current line number
       INC    HL
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       EX     DE,HL           ; DE points 1 byte before start of actual line
       ADD    HL,DE           ; form address of next line in HL
       INC    HL
       
; Consider next BASIC line; HL points to end, DE one byte before start
; Applies to both program lines and direct commands       
       
NEXT_LINE
       LD     (23637),HL      ; set NXTLIN
       EX     DE,HL
       LD     (23645),HL      ; set CH_ADD
       LD     D,A             ; statement number to D
       LD     E,#00
       LD     (IY+10),#FF     ; signal 'no jump yet' in NSPPC
       DEC    D               
       LD     (IY+13),D       ; set SUBPPC
       JP     Z,STMT_LOOP     ; jump if zero (STMT_LOOP increases it again)
       INC    D               ; restore original statement number
       CALL   #198B           ; call EACH-STMT to find statement in line
       JP     NZ,#1BEC        ; if not found, report error N
       
; check if we're at the end of a statement - else report 'Nonsense in BASIC'       
       
ST_NEXT
       RST    #18             ; get current char
       CP     #0D             ; end of line?
       JR     Z,LINE_END      ; yes
       CP     #3A             ; are we on a ':'?
       JP     Z,STMT_LOOP     ; yes, next statement
       RST    8               ; else, give report C
       DEFB   #0B

;COMMAND_CLASS TABLE

CL0    DEFB   CL00-$
       DEFB   CL01-$
       DEFB   CL02-$
       DEFB   CL03-$
       DEFB   CL04-$
       DEFB   CL05-$
       DEFB   CL06-$
       DEFB   CL07-$
       DEFB   CL08-$
       DEFB   CL09-$
       DEFB   CL0A-$
       DEFB   CL0B-$

CL03   CALL   FETCH_NUM       ; get number but use zero by default
CL00   CP     A               ; class 00 - no (further) operands
CL05   POP    BC              ; class 05 - end of table entry, drop SCAN_LOOP
       CALL   Z,CH_END        ; if class 00, check if we're at the end
       EX     DE,HL           ; save pointer in DE
JUMPCR LD     HL,(23668)      ; get T_ADDR pointer
       LD     C,(HL)          ; it points to the current command's handler
       INC    HL              ; address
       LD     B,(HL)
       EX     DE,HL           ; restore line pointer in HL
       PUSH   BC              ; push handler's address
       RET                    ; and make a indirect jump to it

CL01   CALL   LOOKVARS        ; Class 01 - a variable name must follow

VAR_A1 LD     (IY+55),#00     ; initialise FLAGX
       LD     (23666),BC      ; set STRLEN
       JR     NC,VAR_A2       ; jump if existing variable
       SET    1,(IY+55)       ; signal 'new variable'
       JR     NZ,VAR_A3       ; but do not allow undimensioned arrays
       RST    8               ; Report 2 - 'Variable not found'
       DEFB   #01
VAR_A2 CALL   Z,DESTAD        ; find address of array element
VAR_A3 LD     (23629),HL      ; set DEST
       RET

CL02   POP    BC              ; Class 02 - drop SCAN-LOOP

; Fetch a value and assign it to a variable - used by LET, READ and INPUT

V_FET1 LD     A,(23611)       ; save FLAGS
V_FET2 PUSH   AF
       CALL   SCANNING        ; evaluate expression
       POP    AF              ; get old FLAGS or FLAGX
       XOR    (IY+1)          
       AND    #40             ; compare bit 6 which signals numeric or string
       JR     NZ,RPRT_C       ; 'Nonsense in BASIC' if types mismatch
       JP     LET             ; else, do the assignment

CL04   CALL   LOOKVARS        ; class 04 - used by FOR
       PUSH   AF              ; save flags
       LD     A,C             ; get type byte in bits 5 and 6
       OR     #9F             ; they should both be 1 for 'simple numeric
       INC    A               ; variable'
       JR     NZ,RPRT_C       ; give 'Nonsense in BASIC' if not
       POP    AF              ; restore flags
       JR     VAR_A1          ; go assign the FOR variable

; Evaluate numeric parameters
       
NXT_2NUM                      ; this entry skips to next character
       RST    #20
CL08                          ; class 08 - two parameters must follow
EX_2NUM
       CALL   EX_1NUM         ; evaluate first
       CP     ","
       JR     NZ,RPRT_C       ; a comma must follow
       RST    #20             ; advance to next
CL06                          ; class 06 - a numeric expression must follow
EX_1NUM
       CALL   SCANNING        ; evaluate the expression
       BIT    6,(IY+1)        ; bit 6 of FLAGS should be set
       RET    NZ              ; return if OK - else report syntax error
RPRT_C RST    8               ; Report C - 'Nonsense in BASIC'
       DEFB   #0B
CL0A                          ; Class 0A - A string expression must follow
EX_EXP CALL   SCANNING
       BIT    6,(IY+1)        ; bit 6 of FLAGS should be reset
       JR     NZ,RPRT_C       ; else, report error
       RET

; Check end of statement reached
       
CH_END CALL   #2048
       RET    Z
       JR     RPRT_C

; Class 07 - used by colour commands to make temporary colours permanent
       
CL07   CALL   #0D4D
       POP    AF
       LD     A,(23668)
       SUB    #13
       CALL   CO_T4
       JP     #1CAD

; Class 09 - used by PLOT, DRAW and CIRCLE commands
       
CL09   RES    0,(IY+2)
       CALL   #0D4D
       LD     HL,#5C90
       LD     A,(HL)
       OR     #F8
       LD     (HL),A
       RES    6,(IY+87)
       RST    #18
       CALL   CO_T2
       JR     EX_2NUM

; Class 0B - Cassette commands
       
CL0B   JP     SAVE_ETC

; Fetch a number; use zero by default

FETCH_NUM
       CP     #0D
       JR     Z,USE_ZERO
       CP     #3A
       JR     NZ,EX_1NUM
USE_ZERO
       RST    #28
       DEFB   #A0,#38         ; stack-zero
       RST    #18             ; get next character
       RET

; IF command
       
IF     POP    BC              ; drop STMT-RET
       RST    #28
       DEFB   #02,#38         ; delete value from stack
       EX     DE,HL           ; but point HL at value
       CALL   #34E9           ; and test for zero
       JP     C,LINE_END      ; if zero ('false'), jump to next line
       JP     ST_L_1          ; else go to statement after THEN

; FOR command
; This stores 18 bytes on the stack:
; Byte  0:          $EB (FOR marker)
; Bytes 1-2:        Address of FOR variable in VARS area
; Bytes 3-7:        Limit value
; Bytes 8-12:       Step value
; Byte  13:         Statement number after FOR
; Bytes 14-15:      Line number of FOR statement
; Bytes 16-17:      Address offset in PROG/E_LINE
       
FOR    CP     #CD
       JR     NZ,USE1
       RST    #20
       CALL   EX_1NUM
       JR     REORDER
USE1   RST    #28
       DEFB   #A1,#38
REORDER
       RST    #28
       DEFB   #C0,#02,#01
       DEFB   #E0,#01,#38
       CALL   LET
       LD     E,(IY+57)
       LD     D,0
       SCF
       SBC    HL,DE
       LD     DE,(23627)
       SBC    HL,DE
       LD     (23629),HL
       BIT    1,(IY+55)
       JR     NZ,F_CONT
       LD     B,H
       LD     C,L
       LD     HL,4
       ADD    HL,SP
STK_LP LD     A,(HL)
       AND    A
       JR     Z,F_CONT
       CP     #EB
       JR     Z,F_TEST
       LD     DE,6
F_NEXT ADD    HL,DE
       JR     STK_LP
F_TEST INC    HL
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       EX     DE,HL
       SBC    HL,BC
       EX     DE,HL
       LD     DE,16
       JR     NZ,F_NEXT
       CALL   REC_ENTRY
F_CONT CALL   STMTAD
       POP    BC
       EX     (SP),HL
       EX     DE,HL
       LD     HL,(23621)
       PUSH   HL
       LD     A,(23623)
       PUSH   AF
       LD     HL,-9
       ADD    HL,SP
       LD     SP,HL
       PUSH   HL
       LD     HL,(23629)
       EX     (SP),HL
       LD     A,#EB
       PUSH   AF
       INC    SP
       PUSH   DE
       LD     (23613),SP
       PUSH   BC
       PUSH   HL
       RST    #28
       DEFB   #02,#02,#38
       POP    HL
       EX     DE,HL
       LD     BC,10
       LDIR
       RET

NEXT_1 RST    #20
NEXT   LD     HL,4
       ADD    HL,SP
NXT_LP LD     A,(HL)
       CP     #EB
       JP     NZ,#1DD8
       INC    HL
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       PUSH   HL
       LD     HL,(23627)
       ADD    HL,DE
       EX     DE,HL
       RST    #18
       EX     DE,HL
       CALL   #2C8D
       JR     NC,NEXT_2
       PUSH   DE
NXTNAM OR     #20
       CP     (HL)
       JR     Z,NXT_UPD
NXTPTR POP    HL
       LD     (23645),HL
       POP    HL
       LD     DE,16
       ADD    HL,DE
       JR     NXT_LP
NXT_UP INC    HL
       EX     DE,HL
       RST    #20
       EX     DE,HL
       CALL   #2C88
       JR     C,NXTNAM
       LD     A,(HL)
       AND    A
       JR     NZ,NXTPTR
       POP    DE
NEXT_2 XOR    A
       LD     B,1
       CPIR
       LD     (23656),HL
       POP    HL
       PUSH   HL
       INC    HL
       CALL   #33B4
       CALL   #33B4
       RST    #28
       DEFB   #31,#E0,#0F
       DEFB   #C0,#01,#36
       DEFB   #00,#02,#01
       DEFB   #03,#37,#00
       DEFB   NEXT_3-$
       DEFB   #38
       POP    HL
       LD     DE,11
       ADD    HL,DE
JUMP   LD     A,(HL)
       LD     (23623),A
       INC    HL
       LD     C,(HL)
       INC    HL
       LD     B,(HL)
       LD     (23621),BC
       INC    HL
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       LD     HL,(23635)
       BIT    7,B
       JR     Z,JP_ADD
       LD     HL,(23641)
JP_ADD ADD    HL,DE
       LD     (23645),HL
       JR     Z,FND_CR
       LD     HL,(23649)
       DEC    HL
       JR     SETNXL
FND_CR LD     A,#0D
       LD     B,A
       CPIR
SETNXL LD     (23637),HL
       RET
NEXT_3 DEFB   #38
       POP    HL
       CALL   REC_ENTRY
NEXT_4 RST    #18
       CP     ","
       JP     Z,NEXT_1
       RET

LOOK_PROG
       LD     A,(HL)
       CP     #3A
       JR     Z,LOOK2
LOOK1  INC    HL
       LD     A,(HL)
       ADD    A,#01
       RET    C
       INC    HL
       INC    HL
       INC    HL
       LD     D,#00
LOOK2  CALL   #198B
       RET    NC
       JR     LOOK1

REC_EN DEC    HL
       DEC    HL
       SCF
       SBC    HL,SP
       LD     B,H
       LD     C,L
       INC    BC
       ADD    HL,SP
       EX     DE,HL
       LD     HL,18
       ADD    HL,DE
       EX     DE,HL
       LDDR
       EX     DE,HL
       INC    HL
       LD     SP,HL
       INC    HL
       INC    HL
       INC    HL
       INC    HL
       LD     (23613),HL
       RET

STMTAD RST    #18
       LD     BC,(23635)
       BIT    7,(IY+12)
       JR     Z,OFFSET
       LD     BC,(23641)
OFFSET SBC    HL,BC
       RET

READ_3 RST    #20
READ   CALL   CL01
       RST    #18
       LD     (23647),HL
       LD     HL,(23639)
       LD     A,(HL)
       CP     #2C
       JR     Z,READ_1
       LD     E,#E4
       CALL   LOOK_PROG
       JP     C,#1E08
READ_1 CALL   #0077
       LD     A,(23611)
       PUSH   AF
       CALL   SCANNING
       CP     ","
       JR     Z,RD_OK
       CALL   #2048
       JP     NZ,#1C8A
RD_OK  POP    AF
       XOR    (IY+1)
       AND    #40
       JR     Z,READ_N
       BIT    6,(IY+1)
       JP     Z,#1C8A
       RST    #28
       DEFB   #2E
       DEFB   #38
READ_N CALL   LET
       RST    #18
       LD     (23639),HL
       LD     HL,(23647)
       LD     (IY+38),#00
       LD     (23645),HL
READ_2 RST    #18
       CP     #2C
       JR     Z,READ_3
       RET

RESTORE
       CALL   #1E99
REST_RUN
       CALL   LN_ADDR
       DEC    HL
       LD     (23639),HL
       RET

RUN    CALL   #1E67
       LD     BC,#0000
       CALL   REST_RUN
       JR     CL_RUN

CLEAR  CALL   SET_PPC
CL_RUN RST    #18
       CALL   #2048
       LD     BC,(23730)
       JR     Z,CLR_1
       CP     ","
       JR     Z,CLR_1
       CALL   EX_1NUM
       CALL   #1E99
CLR_1  PUSH   BC
       RST    #18
       CP     ","
       CALL   Z,#0020
       LD     HL,100
       CALL   #2048
       JR     Z,CLR_2
       CALL   EX_1NUM
       CALL   #1E99
       LD     H,B
       LD     L,C
CLR_2  EX     (SP),HL
       PUSH   HL
       LD     DE,(23627)
       LD     HL,(23641)
       DEC    HL
       CALL   #19E5
       CALL   #0D6B
       LD     HL,(23653)
       LD     DE,50
       ADD    HL,DE
       LD     B,H
       LD     C,L
       POP    DE
       SBC    HL,DE
       JP     NC,#1EDA
       LD     HL,(23732)
       AND    A
       SBC    HL,DE
       JP     C,#1EDA
       EX     DE,HL
       POP    DE
       PUSH   HL
       SBC    HL,DE
       JR     C,RPRT_S
       SBC    HL,BC
       ADD    HL,BC
RPRT_S JP     C,#1F15
       LD     (STRS),HL
       LD     (HL),#00
       POP    DE
       LD     (23730),DE
       LD     (STRPTR),DE
       POP    DE
       POP    BC
       LD     SP,HL
       PUSH   BC
       LD     (23613),SP
       EX     DE,HL
       JP     (HL)

GOTO   CP     "*"
       JR     Z,ON
       CALL   EX_1NUM
       JP     #1E67
ON     RST    #20
       CALL   EX_1NUM
       CP     ";"
       JP     NZ,#1C8A
       CALL   #1E94
ON_LP  PUSH   AF
       RST    #20
       CALL   EX_1NUM
       CALL   #1E99
       POP    AF
       DEC    A
       JP     Z,#1E6A
       LD     C,A
       RST    #18
       CP     ","
       LD     A,C
       JR     Z,ON_LP
       AND    A
       RET

GOSUB  CALL   GOTO
       RET    NC
       RST    #18
       CALL   #2048
       LD     DE,#0200
       CALL   NZ,#198B
       POP    DE
       CALL   STMTAD
       EX     (SP),HL
       LD     BC,(23621)
       PUSH   BC
       LD     B,(IY+13)
       LD     C,#ED
       PUSH   BC
       PUSH   HL
       LD     (23613),SP
       PUSH   DE
       JP     #1F02

RETURN LD     HL,4
       ADD    HL,SP
RET_LP LD     A,(HL)
       AND    A
       JP     Z,#1F38
       CP     #ED
       JR     Z,RET_FND
       LD     DE,18
       ADD    HL,DE
       JR     RET_LP
RET_FN INC    HL
       PUSH   HL
       CALL   JUMP
       POP    HL
       LD     DE,5
       ADD    HL,DE
       POP    DE
       POP    BC
       LD     SP,HL
       PUSH   BC
       LD     (23613),SP
       EX     DE,HL
       JP     (HL)

DEF_FN BIT    7,(IY+12)
       JR     Z,DEFFN1
       CALL   ERROR
       DEFB   #1C
DEFFN1 LD     C,#80
       LD     (23647),HL
       CALL   LOOKV1
       JP     NZ,#1C8A
       LD     C,B
       LD     B,#00
       JR     C,DEFFN2
       PUSH   BC
       SBC    HL,BC
       PUSH   HL
       CALL   NEXT_ONE
       POP    DE
       CALL   #19E5
       POP    BC
DEFFN2 PUSH   BC
       INC    BC
       INC    BC
       INC    BC
       RST    #30
       LD     HL,(23647)
       LD     A,(HL)
       AND    #1F
       LD     C,A
       LD     A,(23611)
       AND    #C0
       OR     C
DEFFN3 LD     (DE),A
       INC    DE
       CALL   #28AB
       CALL   #2C88
       SET    5,A
       JR     C,DEFFN3
       XOR    A
       LD     (DE),A
       RST    #20
       CP     ")"
       JR     Z,DEFFN4
PRM_LP CALL   #2C8D
       JP     NC,#1C8A
       LD     BC,#0001
       RST    #30
       PUSH   DE
PRM_CH OR     #20
       LD     (DE),A
       RST    #30
       RST    #20
       CALL   #2C88
       JR     C,PRM_CH
       EX     DE,HL
       LD     (HL),#00
       POP    HL
       CP     "$"
       JR     NZ,DEFSPC
       RES    6,(HL)
       RST    #20
DEFSPC LD     BC,#0005
       RST    #30
       RST    #18
       CP     ","
       JR     NZ,DEF_BR
       RST    #20
       JR     PRM_LP
DEF_BR CP     ")"
DEFFN4 JP     NZ,#1C8A
       RST    #20
       CP     "="
       JR     NZ,DEFFN4
       RST    #20
       LD     DE,(23635)
       SBC    HL,DE
       PUSH   HL
       LD     BC,#0003
       RST    #30
       EX     DE,HL
       POP    DE
       LD     (HL),#80
       INC    HL
       LD     (HL),E
       INC    HL
       LD     (HL),D
       INC    HL
       LD     DE,(23649)
       AND    A
       SBC    HL,DE
       PUSH   HL
       LD     B,H
       LD     C,L
       LD     HL,(23641)
       DEC    HL
       CALL   #1655
       POP    BC
       PUSH   BC
       LD     HL,(23651)
       DEC    HL
       LDDR
       EX     DE,HL
       INC    HL
       POP    DE
       POP    BC
       ADD    HL,BC
       INC    HL
       EX     DE,HL
       SCF
       SBC    HL,BC
       DEC    HL
       DEC    HL
       EX     DE,HL
       LD     (HL),E
       INC    HL
       LD     (HL),D
       RST    #18
       LD     DE,#0200
       JP     #198B

LPRINT LD     A,#03
       JR     PRINT1
PRINT  LD     A,#02
PRINT1 CALL   #1601
       CALL   #0D4D
PRINT2 RST    #18
       CALL   #2045
       JR     Z,PRINT4
PRINT3 CALL   #204E
       JR     Z,PRINT3
       CALL   PR_ITEM
       CALL   #204E
       JR     Z,PRINT3
       CALL   #2045
       JR     NZ,PRINT3
PRINT4 CP     #29
       RET    Z
PR_CR  LD     A,#0D
       RST    #10
       RET
PR_ITEM
       RST    #18
       CP     #AC
       JR     NZ,PR_I2
       CALL   NXT_2NUM
       JP     #2007
PR_I2  CP     #AD
       JR     NZ,PR_I3
       RST    #20
       CALL   EX_1NUM
       JP     #2019
PR_I3  CALL   CO_T3
       RET    NC
       CALL   STR_ALT
       RET    NC
       CALL   SCANNING
       JP     #2032

STR_ALT
       CP     #23
       SCF
       RET    NZ
       RST    #20
       CALL   EX_1NUM
       JP     #207C

INPUT  LD     A,#02
       CALL   #1601
IN_IT1 CALL   #204E
       JR     Z,IN_IT1
       CP     "("
       JR     NZ,IN_IT2
       RST    #20
       CALL   PRINT2
       RST    #18
       CP     ")"
       JP     NZ,#1C8A
       RST    #20
       JP     IN_NX2
IN_IT2 CALL   #2C8D
       JP     NC,IN_NX1
       CALL   CL01
       LD     HL,(23645)
       PUSH   HL
       JR     IN_SAV
IN_BAD SET    6,(IY+1)
       LD     (IY+0),#FF
       LD     (IY+82),#03
       XOR    A
       LD     DE,IN_MSG
       CALL   #0C0A
       POP    HL
       LD     (23613),HL
IN_SAV LD     HL,(23613)
       PUSH   HL
       LD     HL,IN_BAD
       PUSH   HL
       CALL   #16BF
       LD     (IY+82),#02
IN_ED  CALL   #15DE
       LD     C,A
       SCF
       LD     A,(BRKFLG)
       DEC    A
       CALL   NZ,#1F54
       JP     NC,#0D00
       LD     A,C
       CP     #0D
       JR     Z,IN_SP
       CALL   IN_CHAN_S
       JR     NZ,IN_SP
       CP     #20
       JR     C,IN_ED
       CP     #7F
       JR     NZ,IN_SP
       LD     HL,(23651)
       LD     DE,(23649)
       DEC    HL
       SBC    HL,DE
       ADD    HL,DE
       JR     C,IN_ED
       LD     BC,1
       CALL   #19E8
       LD     A,#7F
       RST    #10
       JR     IN_ED
IN_SP  CALL   IN_CHAN_S
       PUSH   AF
       CALL   Z,#0010
       POP    AF
       LD     BC,1
       RST    #30
       LD     (DE),A
       CP     #0D
       JR     NZ,IN_ED
       BIT    6,(IY+1)
       JR     Z,IN_STR
       CALL   IN_CHAN_S
       JR     NZ,IN_WORK
       LD     (23613),SP
IN_WOR LD     HL,(23649)
       LD     (23645),HL
       CALL   EX_1NUM
       CP     #0D
       JR     Z,IN_ASSIGN
       RST    8
       DEFB   #0B
IN_STR LD     HL,(23651)
       LD     DE,(23649)
       SCF
       SBC    HL,DE
       LD     B,H
       LD     C,L
       CALL   #2AB2
IN_ASS POP    HL
       POP    HL
       LD     (23613),HL
       POP    HL
       LD     (23645),HL
       CALL   LET
       JR     IN_NX2
IN_NX1 CALL   PR_ITEM
IN_NX2 CALL   #204E
       JP     Z,IN_IT1
       RET

IN_CHAN_S
       LD     C,A
       LD     HL,(23633)
       INC    HL
       INC    HL
       INC    HL
       INC    HL
       LD     A,(HL)
       CP     "S"
       LD     A,C
       RET

IN_MSG DEFB   #80
       DEFM   "INPUT ERROR; REENTER"
       DEFB   #8D

CO_T1  RST    #20
CO_T2  CALL   CO_T3
       RET    C
       RST    #18
       CP     #2C
       JR     Z,CO_T1
       CP     #3B
       JR     Z,CO_T1
CO_RPC RST    8
       DEFB   #0B
CO_T3  CP     #D9
       RET    C
       CP     #DF
       CCF
       RET    C
       PUSH   AF
       RST    #20
       POP    AF
CO_T4  SUB    #C9
       PUSH   AF
       CALL   EX_1NUM
       CALL   #1E94
       LD     D,A
       POP    AF
       RST    #10
       LD     A,D
       RST    #10
       RET

CIRCLE RST    #18
       CP     ","
       JR     NZ,CO_RPC
       RST    #20
       CALL   EX_1NUM
       JP     #232D

PLOT   CALL   #2307
       CALL   PL_SUB
       JP     #0D4D

PL_SUB LD     (23677),BC
       LD     A,#BF
       CALL   #22AC
       JP     #22EC

DRAW   RST    #18
       CP     ","
       JR     NZ,LN_DRAW
       RST    #20
       CALL   EX_1NUM
       JP     #2394

LN_DRA CALL   #2307
       LD     A,C
       CP     B
       JR     NC,X_GE_Y
       LD     L,C
       PUSH   DE
       XOR    A
       LD     E,A
       JR     LARGER
X_GE_Y OR     C
       JP     Z,#0D4D
       LD     L,B
       LD     B,C
       PUSH   DE
       LD     D,#00
LARGER LD     H,B
       LD     A,B
       RRA
DL_LOO ADD    A,L
       JR     C,DIAG
       CP     H
       JR     C,HR_VT
DIAG   SUB    H
       LD     C,A
       EXX
       POP    BC
       PUSH   BC
       JR     DL_STEP
HR_VT  LD     C,A
       PUSH   DE
       EXX
       POP    BC
DL_STE LD     HL,(23677)
       LD     A,B
       ADD    A,H
       LD     B,A
       LD     A,C
       INC    A
       ADD    A,L
       JR     C,DL_RANGE
       JR     Z,RPRT_B
DL_PLO DEC    A
       LD     C,A
       CALL   PL_SUB
       EXX
       LD     A,C
       DJNZ   DL_LOOP
       POP    DE
       JP     #0D4D
DL_RAN JR     Z,DL_PLOT
RPRT_B RST    8
       DEFB   #0A

;EXPRESSION EVALUATION

SCANNING
       RST    #18
       LD     B,#00
       PUSH   BC
S_LP1  LD     C,A
       LD     HL,SF_TABLE
       CALL   #16DC
       LD     A,C
       JP     NC,S_ALPNUM
       LD     B,#00
       LD     C,(HL)
       ADD    HL,BC
       JP     (HL)

S_2COORD
       RST    #20
       CP     "("
       JR     NZ,S_RPC
       CALL   NXT_2NUM
       RST    #18
       CP     ")"
S_RPC  JP     NZ,#1C8A
       RET

SF_TABLE
       DEFB   #22
       DEFB   S_QUOTE-$
       DEFB   #28
       DEFB   S_BRACKET-$
       DEFB   #2E
       DEFB   S_DEC-$
       DEFB   #2B
       DEFB   S_UPLUS-$
       DEFB   #A8
       DEFB   S_FN-$
       DEFB   #A5
       DEFB   S_RND-$
       DEFB   #A7
       DEFB   S_PI-$
       DEFB   #A6
       DEFB   S_INK$-$
       DEFB   #C4
       DEFB   S_BIN-$
       DEFB   #AA
       DEFB   S_SCR$-$
       DEFB   #AB
       DEFB   S_ATTR-$
       DEFB   #A9
       DEFB   S_POINT-$
       DEFB   #00

S_UPLUS
       RST    #20
       JP     S_LP1

S_QUOTE
       RST    #18
       INC    HL
       PUSH   HL
       LD     BC,#0000
       CALL   #250F
       DEC    BC
       POP    DE
S_STRING
       CALL   #2AB2
       JP     CONT2

S_BRACKET
       RST    #20
       CALL   SCANNING
       CP     ")"
       JP     NZ,#1C8A
       RST    #20
       JP     CONT2

S_FN   JP     SF_SUB

S_RND  LD     BC,(23670)
       CALL   #2D2B
       RST    #28
       DEFB   #A1,#0F,#34
       DEFB   #37,#16,#04
       DEFB   #34,#80,#41
       DEFB   #00,#00,#80
       DEFB   #32,#02,#A1
       DEFB   #03,#31,#38
       CALL   #2DA2
       LD     (23670),BC
       LD     A,(HL)
       AND    A
       JR     Z,S_PI_END
       SUB    #10
       LD     (HL),A
       JR     S_PI_END
S_PI   RST    #28
       DEFB   #A3,#38
       INC    (HL)
S_PI_END
       RST    #20
       JP     S_NUMERIC
S_INK$ LD     BC,#105A
       RST    #20
       CP     "#"
       JP     Z,S_PUSHPO
       RES    6,(IY+1)
       CALL   #028E
       LD     C,#00
       JR     NZ,IN$STK
       CALL   #031E
       JR     NC,IN$STK
       DEC    D
       LD     E,A
       CALL   #0333
       LD     BC,#0001
       RST    #30
       LD     (DE),A
       LD     C,#01
IN$STK LD     B,#00
S_STR  CALL   #2AB2
       JP     CONT2

S_SCR$ CALL   S_2COORD
       CALL   SCREEN$
       RST    #20
       JR     S_STR

S_ATTR CALL   S_2COORD
       CALL   #2580
       RST    #20
       JR     S_NUMERIC

S_POINT
       CALL   S_2COORD
       CALL   #22CB
       RST    #20
       JR     S_NUMERIC

S_ALPNUM
       CALL   #2C88
       JR     NC,NEGATE
       CP     #41
       JR     NC,S_LETTER

S_DEC  CALL   NOTBIN
       JR     S_BIN1
S_BIN  CALL   #2C9F
S_BIN1 LD     HL,(23645)
       LD     A,(HL)
       CALL   #18B6
       LD     (23645),HL
       JR     S_NUMERIC
NOTBIN CP     "."
       JP     Z,VALSUB
       RST    #18
       PUSH   HL
       CALL   INT_TO_BC
       CALL   NC,#2D2B
       POP    HL
       JR     NC,DEC_TST
       CALL   #0078
       CALL   #2D3B
DEC_TST
       RST    #28
       DEFB   #A1,#C2,#02
       DEFB   #38
       LD     HL,(23645)
       LD     A,(HL)
       JP     VALFRC

S_NUMERIC
       SET    6,(IY+1)
       JR     CONT2

S_LETTER
       CALL   LOOKVARS
       JR     NC,TST_VAR
       JP     Z,#1C2E
       RST    #28
       DEFB   #A0,#38
       JR     CONT2
TST_VA CALL   Z,DESTAD
       INC    HL
       BIT    6,(IY+1)
       JR     Z,STKSTR
       CALL   #33B4
       JR     CONT2
STKSTR LD     A,(HL)
       INC    HL
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       INC    HL
       LD     C,(HL)
       INC    HL
       LD     B,(HL)
       AND    A
       JR     Z,S_STK
       LD     HL,(23635)
       ADD    HL,DE
       EX     DE,HL
S_STK  CALL   #2AB6
       JR     CONT2

NEGATE LD     BC,#09DB
       CP     "-"
       JR     Z,S_PUSHPO
       SUB    #AF
       JP     C,#1C8A
       LD     BC,#04F0
       CP     #14
       JR     Z,S_PUSHPO
       JP     NC,#1C8A
       LD     B,#10
       ADD    A,#DC
       LD     C,A
       CP     #DF
       JR     NC,NO_$
       RES    6,C
NO_$   CP     #EE
       JR     C,S_PUSHPO
       RES    7,C
S_PUSHPO
       PUSH   BC
       RST    #20
       JP     S_LP1

CONT2  RST    #18
       LD     B,#00
       LD     C,A
       LD     HL,#2795
       CALL   #16DC
       JR     NC,S_LOOP
       LD     C,(HL)
       LD     HL,#26ED
       ADD    HL,BC
       LD     B,(HL)
S_LOOP POP    DE
       LD     A,D
       CP     B
       JR     C,S_TIGHTER
       AND    A
       JP     Z,#0018
       PUSH   BC
       LD     HL,#5C3B
       LD     A,E
       CP     #ED
       JR     NZ,STK_LST
       BIT    6,(HL)
       JR     NZ,STK_LST
       LD     E,#99
STK_LST
       PUSH   DE
       LD     A,(HL)
       XOR    E
       AND    #40
S_ERR  JP     NZ,#1C8A
       LD     A,E
       AND    #3F
       CP     #1D
       JR     Z,S_VAL
       CP     #06
       JR     NZ,S_CALC
       RST    #28
       DEFB   #01,#31,#36
       DEFB   #00,LESS0-$
       DEFB   #01,#06,#38
       JR     S_TEST
LESS0  DEFB   #2A,#25,#01
       DEFB   #31,#31,#27
       DEFB   #03,#38
       CALL   #34E9
       JP     NC,#34E7
       RST    #28
       DEFB   #02,#31,#34
       DEFB   #40,#B0,#00
       DEFB   #02,#05,#31
       DEFB   #27,#03,#38
       CALL   #34E9
       PUSH   AF
       RST    #28
       DEFB   #02,#04,#26
       DEFB   #38
       POP    AF
       CALL   NC,#346E
       JR     S_TEST
S_VAL  CALL   VAL
       JR     S_TEST
S_CALC LD     B,A
       RST    #28
       DEFB   #3B,#38
S_TEST POP    DE
       LD     HL,#5C3B
       SET    6,(HL)
       BIT    7,E
       JR     NZ,LOOPEND
       RES    6,(HL)
LOOPEND
       POP    BC
       JR     S_LOOP
S_TIGHTER
       PUSH   DE
       LD     A,C
       BIT    6,(IY+1)
       JR     NZ,S_NEXT
       AND    #3F
       ADD    A,#08
       LD     C,A
       CP     #10
       JR     NZ,NOT_AND
       SET    6,C
       JR     S_NEXT
NOT_AN JR     C,S_ERR
       CP     #17
       JR     Z,S_NEXT
       SET    7,C
S_NEXT PUSH   BC
       RST    #20
       JP     S_LP1

SF_SUB RST    #20
       LD     C,#80
       CALL   LOOKV1
       JP     C,#2812
       PUSH   BC
       EX     DE,HL
       RST    #20
       EX     DE,HL
       INC    HL
       INC    HL
       INC    HL
       PUSH   HL
       LD     A,(HL)
       CP     #80
       JR     Z,SF_BR2
SF_ARG PUSH   HL
       CALL   SCANNING
       POP    HL
       LD     A,(#5C3B)
       XOR    (HL)
       AND    #40
       JR     NZ,SF_MIS
       LD     B,#01
       CPIR
       EX     DE,HL
       LD     HL,(#5C65)
       LD     BC,#0005
       SBC    HL,BC
       LD     (#5C65),HL
       BIT    6,(IY+1)
       JR     NZ,SF_CPY
       LD     (HL),A
SF_CPY LDIR
       EX     DE,HL
       LD     A,(HL)
       CP     #80
       JR     Z,SF_BR2
       EX     DE,HL
       RST    #18
       CP     #2C
       JR     NZ,SF_DEF
       RST    #20
       EX     DE,HL
       JR     SF_ARG
SF_DEF EX     DE,HL
SFD_LP XOR    A
       LD     B,1
       CPIR
       DEC    A
       LD     (HL),A
       INC    A
       INC    HL
       LD     B,4
SFDFIL LD     (HL),A
       INC    HL
       DJNZ   SFDFIL
       LD     A,(HL)
       CP     #80
       JR     NZ,SFD_LP
SF_BR2 EX     DE,HL
       RST    #18
       CP     #29
SF_MIS JP     NZ,#288B
       EX     DE,HL
       INC    HL
       LD     C,(HL)
       INC    HL
       LD     B,(HL)
       LD     HL,(#5C53)
       ADD    HL,BC
       LD     (#5C5D),HL
       LD     HL,(#5C0B)
       EX     (SP),HL
       LD     (#5C0B),HL
       PUSH   DE
       CALL   SCANNING
       POP    HL
       LD     (#5C5D),HL
       POP    HL
       LD     (#5C0B),HL
       POP    BC
       LD     A,(#5C3B)
       XOR    C
       AND    #40
       JR     NZ,LV_RPC
       RST    #20
       JP     CONT2

; LOOKVARS routine
; The format used by the BEXT interpreter for storing variables differs
; significantly from the Spectrum's interpreter's, since we allow names
; of string-, array- and FOR-NEXT variables with 2 or more characters.
; DEFFN functions are also stored here, with space for storing the argument
; values (which is in fact a local VARS area).
; Usage of first byte:
;   bits 0-4 first letter of name (01h-1Ah)
;   bit 5: 1 for ordinary numeric or string variable, 0 for arrays & FNs
;   bit 6: 1 for numeric type (simple/array/FN), 0 for string type
;   bit 7: 1 means a DEFFN function
; Second, third and so on byte: subsequent characters of name (lowercase)
; All names are null-terminated, all characters are significant
; For arrays and FNs, the next two bytes define the length of following block
; All simple variables and array elements have 5 bytes. For strings these are
; as follows:
; Byte 0: 0 means absolute address, <>0 means relative address (to PROG)
; Byte 1-2: pointer to string (absolute or relative, see byte 0)
; Byte 3-4: length of string
;
; DEFFN functions:
; +------+---+--------+--------+------+-----+--------+--------+
; | name | 0 | len-lo | len-hi | args | 80h | ptr-lo | ptr-hi |
; +------+---+--------+--------+------+-----+--------+--------+
; args is a local variable storage (terminated by 80h)
; ptr is pointer to the function definition, relative to PROG

LOOKVARS
       LD     C,#00
LOOKV1 RST    #18
       CALL   #2C8D
       JR     NC,LV_RPC
       PUSH   HL
       AND    #1F
       OR     C
       LD     C,A
       LD     B,#01
V_CHAR RST    #20
       CALL   #2C88
       JR     NC,V_TEST
       INC    B
       JR     NZ,V_CHAR
LV_RPC RST    8
       DEFB   #0B
V_TEST CP     #24
       JR     NZ,V_ARRAY
       RES    6,(IY+1)
       RST    #20
       CP     #28
       JR     Z,V_SEARCH
       SET    5,C
       JR     V_FN
V_ARRAY
       SET    6,(IY+1)
       SET    6,C
       CP     #28
       JR     Z,V_SEARCH
       SET    5,C
V_FN   LD     A,(#5C0C)
       AND    A
       JR     Z,V_SEARCH
       LD     HL,V_RETAD
       EX     (SP),HL
       PUSH   HL
       LD     HL,(#5C0B)
       JR     V_EACH
V_RETAD
       RET    NC
       PUSH   HL
V_SEARCH
       LD     HL,(#5C4B)
V_EACH LD     A,(HL)
       CP     #80
       JR     Z,V_80
       CP     C
       JR     NZ,V_NEXT
       POP    DE
       PUSH   DE
       PUSH   BC
       PUSH   HL
       DEC    B
       JR     Z,V_CHECK
V_MATCH
       INC    HL
V_SP   INC    DE
       LD     A,(DE)
       CP     #21
       JR     C,V_SP
       OR     #20
       CP     (HL)
       JR     NZ,V_PTR
       DJNZ   V_MATCH
V_CHECK
       INC    HL
       LD     A,(HL)
       AND    A
       JR     Z,V_FOUND
V_PTR  POP    HL
       POP    BC
V_NEXT CALL   NEXT_ONE
       JR     V_EACH
V_80   POP    HL
       SCF
       BIT    5,C
       RET
V_FOUND
       POP    BC
       POP    BC
       POP    DE
       BIT    5,C
       RET

NEXT_ONE
       BIT    5,(HL)
       PUSH   AF
N_O_1  LD     A,(HL)
       INC    HL
       AND    A
       JR     NZ,N_O_1
       LD     DE,#0005
       POP    AF
       JR     NZ,N_O_2
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       INC    HL
N_O_2  ADD    HL,DE
       RET

DESTAD
       INC    HL
       INC    HL
       INC    HL
       LD     B,(HL)
       EX     DE,HL
       LD     HL,#0000
       PUSH   HL
       JR     D_COUNT
D_COMMA
       PUSH   HL
       RST    #18
       CP     #2C
       JP     NZ,#2A20
D_COUNT
       RST    #20
       POP    HL
       PUSH   BC
       PUSH   HL
       CALL   #2AEE
       EX     (SP),HL
       EX     DE,HL
       DEC    HL
       CALL   INT_EXP
       INC    HL
       CALL   MULT
       ADD    HL,BC
       POP    DE
       POP    BC
       DJNZ   D_COMMA
       PUSH   HL
       RST    #18
       CP     #29
       JP     NZ,#2A20
       RST    #20
       POP    HL
       BIT    6,C
       LD     B,H
       LD     C,L
       ADD    HL,HL
       ADD    HL,HL
       ADD    HL,BC
       ADD    HL,DE
       RET    NZ
       RES    6,(IY+1)
       RET
INT_EXP
       PUSH   DE
       PUSH   HL
       CALL   EX_1NUM
       CALL   #1E99
       POP    HL
       POP    DE
       SBC    HL,BC
       ADD    HL,BC
       RET    NC
       RST    8
       DEFB   #02

GET_HL CALL   MULT
       JP     C,#1F15
       RET

MULT   XOR    A
       SBC    HL,DE
       ADD    HL,DE
       JR     NC,MU1
       EX     DE,HL
MU1    CP     D
       RET    C
       OR     E
       LD     E,D
       JR     NZ,MU4
       EX     DE,HL
       RET
MU2    EX     DE,HL
       ADD    HL,DE
       EX     DE,HL
MU3    ADD    HL,HL
       RET    C
MU4    RRA
       JR     NC,MU3
       AND    A
       JR     NZ,MU2
       ADD    HL,DE
       RET

LET    BIT    6,(IY+1)
       JR     NZ,L_NUM
       CALL   L_PAR
       CALL   #2AB2
L_NUM  LD     HL,(23629)
       BIT    1,(IY+55)
       JR     Z,L_EXIST
       LD     L,(IY+57)
       LD     H,#00
       LD     BC,#0006
       ADD    HL,BC
       LD     B,H
       LD     C,L
       LD     HL,(23641)
       DEC    HL
       CALL   #1655
       INC    HL
       EX     DE,HL
       LD     HL,(23629)
       LD     BC,(23666)
       LD     A,C
L_CHAR LD     (DE),A
       INC    DE
L_SPC  INC    HL
       LD     A,(HL)
       CP     #21
       JR     C,L_SPC
       OR     #20
       DJNZ   L_CHAR
       XOR    A
       LD     (DE),A
       EX     DE,HL
L_EXIS INC    HL
       EX     DE,HL
       LD     HL,(23653)
       LD     BC,#0005
       AND    A
       SBC    HL,BC
       LD     (23653),HL
       PUSH   DE
       LDIR
       POP    HL
       RET

L_PAR  CALL   #2BF1
       LD     A,B
       OR     C
       JR     NZ,NO_NULL
       LD     D,B
       LD     E,C
       RET
NO_NUL XOR    A
       SBC    HL,DE
       RET    C
       LD     HL,(23641)
       SCF
       SBC    HL,DE
       JR     NC,L_PROG
       LD     HL,(STRPTR)
       AND    A
       SBC    HL,BC
       INC    HL
       PUSH   DE
       EX     DE,HL
       LD     HL,(STRS)
       SBC    HL,DE
       JR     C,L_OK
       PUSH   BC
       CALL   GARBAGE
       POP    BC
       LD     HL,(STRPTR)
       AND    A
       SBC    HL,BC
       INC    HL
       EX     DE,HL
       LD     HL,(STRS)
       SBC    HL,DE
       JR     C,L_OK
       CALL   ERROR
       DEFB   #1B
L_OK   POP    HL
       DEC    DE
       LD     (STRPTR),DE
       INC    DE
       PUSH   DE
       PUSH   BC
       LDIR
       POP    BC
       POP    DE
       XOR    A
       RET
L_PROG LD     HL,(23635)
       EX     DE,HL
       LD     A,#01
       SBC    HL,DE
       EX     DE,HL
       RET    NC
       ADD    HL,DE
       EX     DE,HL
       XOR    A
       RET

G_NXT1 INC    HL
       INC    HL
       INC    HL
G_NEXT DEC    BC
       LD     A,B
       OR     C
       JR     NZ,G_ELEM
G_VAR  LD     A,(HL)
       CP     #80
       RET    Z
       RRCA
       OR     (HL)
       AND    #40
       JR     Z,G_STR
       CALL   NEXT_ONE
       JR     G_VAR
G_STR  LD     E,(HL)
       LD     B,#01
       CPIR
       BIT    5,E
       LD     DE,#0001
       JR     NZ,G_COUNT
       INC    HL
       INC    HL
       LD     B,(HL)
       INC    HL
G_MULT LD     A,(HL)
       INC    HL
       PUSH   HL
       LD     H,(HL)
       LD     L,A
       CALL   MULT
       EX     DE,HL
       POP    HL
       INC    HL
       DJNZ   G_MULT
G_COUN LD     B,D
       LD     C,E
G_ELEM LD     A,(HL)
       INC    HL
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       AND    A
       JR     NZ,G_NXT1
       PUSH   HL
       LD     HL,(STRPTR)
       SBC    HL,DE
       JR     NC,G_STRS
       POP    HL
       JR     G_NXT1
G_STRS LD     HL,(STRS)
       SBC    HL,DE
       POP    HL
       JR     NC,G_NXT1
       RET

GARBAG XOR    A
       EX     AF,AF'
       LD     HL,(23730)
       LD     (STRPTR),HL
G_LOOP LD     HL,#0000
       LD     (H_AD),HL
       LD     HL,(23627)
       LD     BC,#0001
G_FETC CALL   G_NEXT
       JR     NC,G_PTRS
       EX     AF,AF'
       LD     A,#01
       EX     AF,AF'
       PUSH   BC
       INC    HL
       LD     C,(HL)
       INC    HL
       LD     B,(HL)
       INC    HL
       PUSH   HL
       EX     DE,HL
       ADD    HL,BC
       EX     DE,HL
       LD     HL,(H_AD)
       SBC    HL,DE
       JR     Z,G_LEN
       JR     NC,G_RSTOR
       LD     HL,#0000
       LD     (H_LEN),HL
       EX     DE,HL
       LD     (H_AD),HL
G_LEN  LD     HL,(H_LEN)
       AND    A
       SBC    HL,BC
       JR     NC,G_RSTOR
       LD     (H_LEN),BC
G_RSTO POP    HL
       POP    BC
       JR     G_FETCH

G_PTRS EX     AF,AF'
       DEC    A
       RET    NZ
       EX     AF,AF'
       LD     HL,(H_AD)
       LD     DE,(STRPTR)
       LD     BC,(H_LEN)
       DEC    HL
       LD     A,B
       OR     C
       JR     Z,G_ENTER
       LDDR
G_ENTE PUSH   DE
       PUSH   HL
       EX     DE,HL
       SBC    HL,DE
       LD     (H_LEN),HL
       LD     HL,(23627)
       LD     BC,#0001
GP_NXT CALL   G_NEXT
       JR     NC,G_END
       EX     (SP),HL
       AND    A
       SBC    HL,DE
       ADD    HL,DE
       EX     (SP),HL
       JR     NC,NO_ADJ
       PUSH   HL
       LD     HL,(H_LEN)
       ADD    HL,DE
       EX     DE,HL
       POP    HL
       LD     (HL),D
       DEC    HL
       LD     (HL),E
       INC    HL
NO_ADJ INC    HL
       INC    HL
       INC    HL
       JR     GP_NXT
G_END  POP    HL
       POP    HL
       LD     (STRPTR),HL
       JP     G_LOOP

FREEME CALL   GARBAGE
       CALL   #1F1A
       LD     HL,(STRPTR)
       LD     DE,(STRS)
       AND    A
       SBC    HL,DE
       SBC    HL,BC
       EX     DE,HL
       LD     HL,(23635)
       LD     BC,(23631)
       SBC    HL,BC
       LD     BC,1043
       SBC    HL,BC
       EX     DE,HL
       JR     NC,FRE_1
       SBC    HL,BC
       JR     NC,FRE_1
       LD     HL,0
FRE_1  LD     B,H
       LD     C,L
       RET

H_AD   DEFW   0
H_LEN  DEFW   0

DIM_1  RST    #20
DIM    LD     (23647),HL
       CALL   LOOKVARS
D_RPC  JP     NZ,#1C8A
       JR     C,D_LETTER
       LD     E,B
       LD     D,#00
       SBC    HL,DE
       PUSH   HL
       CALL   NEXT_ONE
       POP    DE
       PUSH   BC
       CALL   #19E5
       POP    BC
D_LETTER
       LD     H,#00
       LD     L,B
       LD     (H_LEN),HL
       LD     B,H
       PUSH   BC
       LD     L,#05
D_SIZE EX     DE,HL
D_LOOP RST    #20
       LD     H,#FF
       CALL   INT_EXP
       POP    HL
       INC    BC
       PUSH   BC
       INC    H
       PUSH   HL
       LD     H,B
       LD     L,C
       CALL   GET_HL
       EX     DE,HL
       RST    #18
       CP     ","
       JR     Z,D_LOOP
       CP     ")"
       JR     NZ,D_RPC
       RST    #20
       POP    BC
       LD     A,C
       LD     L,B
       LD     H,#00
       INC    HL
       INC    HL
       ADD    HL,HL
       ADD    HL,DE
       JP     C,#1F15
       PUSH   DE
       PUSH   BC
       LD     BC,(H_LEN)
       PUSH   HL
       ADD    HL,BC
       LD     B,H
       LD     C,L
       LD     HL,(23641)
       DEC    HL
       CALL   #1655
       INC    HL
       PUSH   DE
       EX     DE,HL
       LD     HL,(23647)
       LD     (DE),A
D_CHAR INC    DE
D_SP   INC    HL
       LD     A,(HL)
       CP     #21
       JR     C,D_SP
       OR     #20
       LD     (DE),A
       CALL   #2C88
       JR     C,D_CHAR
       EX     DE,HL
       LD     (HL),#00
       POP    DE
       POP    BC
       DEC    BC
       DEC    BC
       DEC    BC
       INC    HL
       LD     (HL),C
       INC    HL
       LD     (HL),B
       POP    AF
       INC    HL
       LD     (HL),A
       LD     H,D
       LD     L,E
       DEC    DE
       LD     (HL),#00
       POP    BC
       LDDR
D_SZ   POP    BC
       LD     (HL),B
       DEC    HL
       LD     (HL),C
       DEC    HL
       DEC    A
       JR     NZ,D_SZ
       RST    #18
       CP     ","
       JP     Z,DIM_1
       RET

INTSRV PUSH   AF
       LD     A,(0)
       CP     #F3
       JR     NZ,INTEND
       PUSH   HL
       LD     HL,(23613)
       DEC    HL
       LD     A,(HL)
       CP     #0F
       JR     NZ,NO_ED
       DEC    HL
       LD     A,(HL)
       CP     #3B
       JR     NZ,NO_ED
       PUSH   DE
       LD     DE,ED_LOOP+3
       LD     (HL),E
       INC    HL
       LD     (HL),D
       INC    HL
       LD     DE,ED_ERROR
       LD     (HL),E
       INC    HL
       LD     (HL),D
       INC    HL
       INC    HL
       INC    HL
       LD     DE,MAIN_3
       LD     (HL),E
       INC    HL
       LD     (HL),D
       POP    DE
NO_ED  POP    HL
INTEND POP    AF
       JP     #0038


       ORG    #FDFD
       JP     INTSRV

       ORG    #FF41
       DEFM   " 2.02  080687  JB "

       ORG    65365
       DEFW   1000
BRKFLG DEFB   0
