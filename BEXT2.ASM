; =============================================================================
; BASICODE-3 v3.1 FOR THE ZX SPECTRUM 48K
; Copyright (C) 1985-2017 by JAN BREDENBEEK, HILVERSUM, THE NETHERLANDS
; RELEASED UNDER GNU v3 PUBLIC LICENSE, 2017

; BEXT SECTION 2: MAIN INTERPRETER ROUTINES
; v2.02; 24 NOVEMBER 1987
; =============================================================================
;
; This code is partly based on the ZX Spectrum ROM's BASIC, which is
; copyrighted by Amstrad plc. However, the Spectrum's ROM has been extensively
; documented in various disassemblies, starting with "The Complete Spectrum
; ROM Disassembly" by Ian Logan and Frank O'Hara (Melbourne House, 1983).
; This disassembly has been the basis of my Basicode EXTension to create an
; alternative interpreter for running BASICODE programs. Parts of the ROM code
; have been taken and modified for BASICODE compatibility while at the same
; time calls and jumps to the ROM code are used as much as possible to save
; space. This means that the presence of the 48K Spectrum's ROM is essential
; for proper operation (at present, the BASICODE extension is compatible with
; the Spectrum 128 models but only in 48K mode).
; In today's world of emulators, it would of course be a nice challenge to make
; the Spectrum ROM's BASIC itself BASICODE compatible so we could save a lot
; of duplicated code in RAM and avoid the dirty tricks necessary to thwart the
; notorious practice by many hardware extensions (including Sinclair's
; Interface 1) to disable our BASICODE interpreter by jumping to various
; locations in the Spectrum's ROM. If you want to take on this challenge by
; using this code in your own ROM you are free to do so, but remember that the
; resulting code might still be covered by Amstrad's copyright. 
; Note that Amstrad has given permission to use the Spectrum ROM's code, even
; in modified form, in emulators as long as you don't charge money for it.
; (source: http://www.shadowmagic.org.uk/spectrum/roms.html).
; -----------------------------------------------------------------------------

;-------------------------------------------------------------------------
; Table containing token codes for modified commands.
; Each entry contains the token code followed by the offset to the
; syntax table entry.
; For any commands not listed here, the ROM table will be used (at $1A48).
;-------------------------------------------------------------------------

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

; -----------------------------------------------------------------------------
; The syntax table for these commands.
; A full explanation can be found in the various Spectrum ROM disassemblies
; But to recap: Codes below $20 are 'command classes' with distinct handling
; routines. Codes above $20 are required separators in the syntax of a command.
; Each entry is terminated by the command's handler address.
; -----------------------------------------------------------------------------

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

; --------------------
; Main statement loop.
; --------------------
       
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
       CALL   #16DC           ; Call INDEXER to lookup the table
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
       
; A jump is to be made in the BASIC program; HL holds new line number
       
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
       LD     (23666),BC      ; save length of name and type in STRLEN
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

;--------------------------
; The FOR and NEXT commands
; -------------------------
; Unlike the ROM, we don't store the limit and step values in a variable.
; Instead, we store them on the machine stack! This has the advantage that a
; FOR-NEXT loop may be terminated using NEXT without a variable, although this
; is against the BASICODE protocol! But unfortunately, this is a mistake made
; in many existing programs so I used this opportunity to be tolerant here...
; Of course, this tolerant approach does have a downside in that FOR-NEXT loops
; must be properly nested (the ROM's BASIC is more forgiving in this respect).
; Some amount of bad behaviour is allowed though - Re-using a FOR variable from
; a previously incomplete loop won't clutter up the stack, and RETURNing from a
; GOSUB will clean up any incomplete FOR loops set up in the subroutine.
;
; When a FOR loop is set up, 18 bytes will be put on the stack:
; Byte  0:          $EB (FOR marker)
; Bytes 1-2:        Address of FOR variable in VARS area
; Bytes 3-7:        Limit value
; Bytes 8-12:       Step value
; Byte  13:         Statement number after FOR
; Bytes 14-15:      Line number of FOR statement
; Bytes 16-17:      Address offset in PROG/E_LINE
;
; Using pointers to the FOR variable and program address will make the loop
; MUCH faster since no time-consuming searches through the PROG and VARS areas
; have to be done with each iteration of the loop! But this comes with a
; penalty: once you've made any modification to the program, you won't be able
; to CONTINUE since all pointers will have been invalidated and the variables
; cleaned up.
; Once again, since most users would use this interpreter for running existing
; BASICODE programs, I chose to sacrifice this feature of ZX BASIC for extra
; speed (which it rather needed compared to other BASICs in its era!).
;
; Note that the FOR-NEXT loop will ALWAYS be executed at least once, even if
; the value has already reached the limit when the FOR statement is executed
; (e.g. FOR I=1 TO N when N is zero)! Although this is strictly speaking wrong,
; it is compatible with the way BASICODE and most other BASICs in the '80s era
; handled this. It is therefore impossible to get a 'FOR without NEXT' error
; message. Also note that FOR-NEXT variables can now have more than one letter
; in their name, unlike in Sinclair BASIC.
;------------------------------------------------------------------------------
       
FOR    CP     #CD             ; Do we have a 'STEP'?
       JR     NZ,USE1         ; No, use STEP value of one
       RST    #20             ; Advance to the value after STEP
       CALL   EX_1NUM         ; Evaluate it
       JR     REORDER         ; Skip forward
USE1   RST    #28             ; A default STEP value of one is to be put onto
       DEFB   #A1,#38         ; the calculator stack (stk-one, end-calc).
REORDER                       ; Now do some re-ordering of the values
       RST    #28             ; FP-stack contains: value, limit, step
       DEFB   #C0,#02,#01     ; now: limit, value (step in MEM-0)
       DEFB   #E0,#01,#38     ; now: limit, step, value
       CALL   LET             ; Call LET to assign the value to the variable
       LD     E,(IY+57)       ; STRLEN-hi holds the length of its name
       LD     D,0             ; this goes to DE
       SCF                    ; HL points to the value, which is after the name
       SBC    HL,DE           ; + null byte; now go back to the start of name
       LD     DE,(23627)      ; VARS
       SBC    HL,DE           ; Find offset of variable's address from VARS
       LD     (23629),HL      ; and enter this into DEST
       BIT    1,(IY+55)       ; Was it a pre-existing variable?
       JR     NZ,F_CONT       ; No, skip
       LD     B,H             ; Offset goes to BC
       LD     C,L
       LD     HL,4            ; The FOR/GOSUB stack starts 4 locations after
       ADD    HL,SP           ; the machine stack

; Now enter a loop to scan the FOR/GOSUB stack for previous incomplete FOR
; loops; these will be reclaimed from the stack.
; Note: Each FOR/GOSUB entry starts with a token byte (FOR/GOSUB); the end
; (or rather bottom) of the stack is marked with a null byte (as opposed to
; the $3E byte in the ROM's version!).

STK_LP LD     A,(HL)          ; Get token byte or end marker
       AND    A               ; Have we reached the bottom of the stack?
       JR     Z,F_CONT        ; Yes, skip
       CP     #EB             ; Is it a FOR entry?
       JR     Z,F_TEST        ; Yes, test it
       LD     DE,6            ; else, assume it's GOSUB which has 6 bytes
F_NEXT ADD    HL,DE           ; .. and skip it
       JR     STK_LP
F_TEST INC    HL              ; Get offset of FOR variable to be tested in DE
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       EX     DE,HL           ; Variable's offset to HL
       SBC    HL,BC           ; Compare against offset of new FOR variable
       EX     DE,HL           ; Switch registers back
       LD     DE,16           ; 16 locations to be skipped
       JR     NZ,F_NEXT       ; Loop back if no match
       CALL   REC_ENTRY       ; Else, reclaim this FOR entry from the stack

; Now we're ready to set up a new FOR loop

F_CONT CALL   STMTAD          ; Find current location relative to PROG/E_LINE
       POP    BC              ; BC now holds return address of STMT_RET
       EX     (SP),HL         ; Exchange statement location with error return
       EX     DE,HL           ; address; this now goes to DE
       LD     HL,(23621)      ; Current line number
       PUSH   HL              ; Push this onto the stack
       LD     A,(23623)       ; Current statement number
       PUSH   AF              ; Push this (high byte, we'll reclaim the lower
       LD     HL,-9           ; byte by allocating 'only' 9 bytes for the limit
       ADD    HL,SP           ; and step value rather than 10)
       LD     SP,HL           ; Set the new machine stack pointer
       PUSH   HL              ; Save the location for limit and step value
       LD     HL,(23629)      ; Get offset of variable to VARS
       EX     (SP),HL         ; Put this on the stack and retrieve HL
       LD     A,#EB           ; The FOR token
       PUSH   AF              ; Push this on the stack as marker
       INC    SP              ; We don't need the flags byte...
       PUSH   DE              ; Push error return point (usually MAIN_4)
       LD     (23613),SP      ; This will be the new ERR_SP
       PUSH   BC              ; Push STMT_RET address
       PUSH   HL              ; Save HL again
       RST    #28             ; Delete limit and step from the calculator stack
       DEFB   #02,#02,#38     ; (but DE will still point to them afterwards)
       POP    HL              ; Retrieve pointer to stack area for limit & step
       EX     DE,HL           ; Switch source and destination
       LD     BC,10           ; Two values means 10 bytes to copy
       LDIR                   ; Now copy limit and step to the stack area
       RET                    ; Finished

;-----------------
; The NEXT handler
; ----------------
; The correct form in BASICODE is:
; FOR I = A TO B
;   FOR J = C TO D
;     ...
;   NEXT J
; NEXT I
;
; However, BASICODE was based on Microsoft BASIC, which allows constructs
; using 'NEXT I,J' or, even worse, 'NEXT:NEXT'. This is NOT allowed in
; in BASICODE, but since M$ BASIC won't complain about it, many such errors
; slipped through quality control (which of course also tested on M$ BASIC)
; and got aired nevertheless. So I decided to be tolerant about it.
; Another problem: Some folks who call themself programmers set up a FOR-NEXT
; loop and then decide they have to get out of it by GOTOing past the NEXT
; (in the above example from the inner loop to the NEXT I), thereby leaving the
; loop active. Again, I did spend some lines and lots of time to tolerate this
; sort of crime (I wonder how M$ BASIC would handle this). So in this case, the
; inner loop will be properly cleaned up from the stack.
;------------------------------------------------------------------------------

NEXT_1 RST    #20             ; Loop after dealing with NEXT I,J - skip comma

; Normal entry point is here

NEXT   LD     HL,4            ; Skip STMT_RET and error return address on stack
       ADD    HL,SP
NXT_LP LD     A,(HL)          ; Get marker byte
       CP     #EB             ; Is it 'FOR'?
       JP     NZ,#1DD8        ; If no FOR on stack, throw 'NEXT without FOR'.

; NOTE: This will also occur when a NEXT is done in a GOSUB'ed subroutine
; called from within a corresponding FOR loop. I can't imagine any useful case
; for this - but there might be folks somewhere around who could. In any case,
; I never got complaints about it :-).

       INC    HL              ; Advance to variable pointer
       LD     E,(HL)
       INC    HL
       LD     D,(HL)          ; Get variable's offset in DE
       PUSH   HL              ; Save pointer to stack address
       LD     HL,(23627)      ; base of VARS
       ADD    HL,DE           ; Form absolute address in HL
       EX     DE,HL           ; Save in DE
       RST    #18             ; Get current character
       EX     DE,HL           ; Variable's address in HL
       CALL   #2C8D           ; Is character after NEXT alphabetic?
       JR     NC,NEXT_2       ; Skip if not
       PUSH   DE              ; Else, save address of current character

; A variable name has been specified after NEXT so we need to match this up
; against the active FOR-NEXT loops on the stack.

NXTNAM OR     #20             ; convert to lower case
       CP     (HL)            ; Match character
       JR     Z,NXT_UPD       ; If it matches, jump to consider next characters
NXTPTR POP    HL              ; Retrieve pointer to current character
       LD     (23645),HL      ; Restore CH_ADD
       POP    HL              ; Retrieve pointer to stack
       LD     DE,16           ; Distance to next stack entry is 16 bytes
       ADD    HL,DE
       JR     NXT_LP          ; Loop for next entry on stack
NXT_UP INC    HL              ; Step to next character
       EX     DE,HL           ; Save DE while the next character in the BASIC
       RST    #20             ; line is fetched
       EX     DE,HL
       CALL   #2C88           ; Is it alphanumeric?
       JR     C,NXTNAM        ; Yes, loop to compare it against variable name
       LD     A,(HL)          ; The end of the variable name after NEXT must
       AND    A               ; also match the end of the variable name in VARS
       JR     NZ,NXTPTR       ; if not, restore pointers and try again
       POP    DE              ; Retrieve pointer to variable name after NEXT

; The FOR-NEXT variable has been identified and its value must be tested
; against the 'limit'.

NEXT_2 XOR    A               ; Look for the NULL byte that terminates the name
       LD     B,1             ; (when coming from a successful name match, this
       CPIR                   ; is simply the next byte after the NULL)
       LD     (23656),HL      ; Set MEMBOT, mem-0 now points to current value
       POP    HL              ; Retrieve address of loop data on stack
       PUSH   HL
       INC    HL              ; Point to the limit value
       CALL   #33B4           ; Put limit value on calculator stack (l)
       CALL   #33B4           ; followed by STEP value (now l, s)
       RST    #28             ; Enter calculator
       DEFB   #31,#E0,#0F     ; duplicate, get-mem-0, add (l, s, v+s)
       DEFB   #C0,#01,#36     ; store-mem-0, exchange, less-0 (l, v+s, s<0)
       DEFB   #00,#02,#01     ; jump-true, (offset), exchange
                              ; (if s<0: l, v+s; else v+s, l)
       DEFB   #03,#37,#00     ; subtract, greater-0, jump-true
       DEFB   NEXT_3-$        ; if limit reached, jump to NEXT_3
       DEFB   #38             ; end-calc
       POP    HL              ; Retrieve pointer to loop data on stack
       LD     DE,11
       ADD    HL,DE           ; Step past limit and step values

; A jump is to be made in the program. HL points to the following data:
;
; - byte  0  : New statement number
; - bytes 1-2: New line number
; - bytes 3-4: Address of character where execution is to be continued
;   This address is either relative to PROG (when executing a program) or
;   E_LINE (when executing a direct command).
;
; Note that this routine directly sets the appropriate system variables,
; without going to the laborious process of setting NEWPPC and NSPPC and
; letting the interpreter search the whole program for the place we want to be.
; After all, we HAVE already been there when executing the FOR or GOSUB
; statement that brought us here!
; This routine is also called from RETURN.

JUMP   LD     A,(HL)          ; Get new statement number
       LD     (23623),A       ; Set SUBPPC
       INC    HL
       LD     C,(HL)          ; Get new line number in BC
       INC    HL
       LD     B,(HL)
       LD     (23621),BC      ; Set PPC
       INC    HL
       LD     E,(HL)          ; Now get offset of next character
       INC    HL              ; to be interpreted
       LD     D,(HL)
       LD     HL,(23635)      ; Assume it's relative to PROG
       BIT    7,B             ; BC will be < 0 when executing a direct command
       JR     Z,JP_ADD        ; Jump with 'real' line numbers
       LD     HL,(23641)      ; Else, it's a direct command - fetch E_LINE
JP_ADD ADD    HL,DE           ; Now form the absolute address in HL
       LD     (23645),HL      ; and set CH_ADD
       JR     Z,FND_CR        ; Zero flag still reset for direct commands
       LD     HL,(23649)      ; When executing a direct command, the end of
       DEC    HL              ; line will be WORKSP - 1
       JR     SETNXL          ; Jump forward

; We still need to set NXTLIN so we need to look for the end of the line,
; marked by a CR character.
; Note: We can do this with a simple CPIR as we don't have to skip-over hidden
; numbers in a program. Direct commands CAN contain hidden numbers, but are
; catered for by the code here above so don't need to be scanned for a CR.
; Since program lines in BASICODE should be <= 60 characters, this search will
; not take very long...

FND_CR LD     A,#0D           ; Search for a CR character
       LD     B,A             ; Set BC reasonable high enough
       CPIR                   ; Now scan the remainder of the line
SETNXL LD     (23637),HL      ; Set NXTLIN
       RET                    ; Done

; Come here when the loop has finished - return from the calculator and clean
; up the loop data on the stack.

NEXT_3 DEFB   #38             ; end-calc
       POP    HL              ; Retrieve pointer to stacked data
       CALL   REC_ENTRY       ; Reclaim this from the stack
NEXT_4 RST    #18             ; Get current character
       CP     ","             ; Test for the form 'NEXT I,J' (strictly illegal
       JP     Z,NEXT_1        ; but tolerated), loop back for next item
       RET                    ; Done with NEXT.

; The LOOK_PROG routine looks for a specific keyword in the program area
; This mimics the equivalent ROM routine, except that this routine handles
; line numbers over 16383. It is called on just one occasion to look for DATA
; statements. In the ROM, it also handled DEF FN and NEXT, but these are
; handled differently here.
; Unlike in Sinclair BASIC, the program area is terminated by a $FF byte after
; the last line.

LOOK_PROG
       LD     A,(HL)          ; HL points after the current statement
       CP     #3A             ; If the next char is ':', jump forward
       JR     Z,LOOK2         ; to consider next statement in the line

; Loop for each new line in the program

LOOK1  INC    HL              ; Skip past the CR at end of each line
       LD     A,(HL)          ; MSB of next line number or $FF marker
       ADD    A,#01           ; An $FF marker will set the carry flag,
       RET    C               ; return if found.
       INC    HL              ; Step past line number and length bytes
       INC    HL
       INC    HL
       LD     D,#00           ; Signal 'count statements to end of line'
LOOK2  CALL   #198B           ; call EACH-STMT in the ROM to find the token
       RET    NC              ; Return carry flag reset if found
       JR     LOOK1           ; Else, loop for next line

; The REC_ENTRY routine reclaims a FOR-NEXT data structure from the FOR/GOSUB
; stack. It is called by the FOR and NEXT handlers.
; On entry, HL points to the third byte of the 18-byte FOR entry.

REC_EN DEC    HL              ; Step 2 bytes down
       DEC    HL
       SCF                    ; Include third byte for subtraction
       SBC    HL,SP           ; Find amount of bytes between FOR entry and
       LD     B,H             ; machine stack; transfer this to BC
       LD     C,L
       INC    BC              ; Include the stack's end-marker byte ($00)
       ADD    HL,SP           ; HL now points to the start of the area to be
       EX     DE,HL           ; reclaimed; save this in DE
       LD     HL,18           ; There are 18 bytes to be reclaimed,
       ADD    HL,DE           ; add this distance to DE
       EX     DE,HL           ; Swap source and destination
       LDDR                   ; .. and copy over the bytes
       EX     DE,HL           ; Swap pointers back
       INC    HL              ; HL now points to top of the machine stack
       LD     SP,HL           ; which has been moved up; set new stack pointer
       INC    HL              ; Step past the return address for this routine
       INC    HL
       INC    HL              ; .. and STMT_RET
       INC    HL
       LD     (23613),HL      ; This will be the new ERR_SP
       RET                    ; Done

; The STMTAD routine returns the offset of the pointer to the current character
; from PROG or E_LINE in HL.

STMTAD RST    #18             ; Get address of current character
       LD     BC,(23635)      ; Fetch PROG
       BIT    7,(IY+12)       ; Test bit 7 of PPC, it will be set when
       JR     Z,OFFSET        ; executing a direct command
       LD     BC,(23641)      ; in that case, offset is from E_LINE
OFFSET SBC    HL,BC           ; Find the offset (carry reset from the RST)
       RET                    ; Done

; ------------------------
; The READ command handler
; ------------------------
; It is entered at READ from the statement loop

READ_3 RST    #20             ; Skip past ',' when handling 'READ a,b,...'
READ   CALL   CL01            ; Call the Class-01 handler to consider the
       RST    #18             ; variable to be assigned; save the pointer
       LD     (23647),HL      ; from CH_ADD temporarily in X_PTR
       LD     HL,(23639)      ; Get current DATA position from DATADD
       LD     A,(HL)
       CP     #2C             ; Are we on a ',' in the DATA statement?
       JR     Z,READ_1        ; Yes, go evaluating it
       LD     E,#E4           ; Else, search the program from the current
       CALL   LOOK_PROG       ; position for a DATA statement
       JP     C,#1E08         ; If not found, report 'Out of DATA'.
READ_1 CALL   #0077           ; Advance pointer and set CH_ADD
       LD     A,(23611)       ; Save FLAGS
       PUSH   AF
       CALL   SCANNING        ; Now call SCANNING to evaluate the expression
                              ; statement in the DATA
       CP     ","             ; The character after the expression must either
       JR     Z,RD_OK         ; be a comma or end of statement (':' or CR)
       CALL   #2048
       JP     NZ,#1C8A        ; Throw 'Nonsense in BASIC' otherwise
RD_OK  POP    AF              ; Restore original FLAGS
       XOR    (IY+1)          ; Compare with result from SCANNING
       AND    #40             ; Bit 6 should match the variable's type
       JR     Z,READ_N        ; Jump forward when they match
       BIT    6,(IY+1)        ; Was the expression of string type?
       JP     Z,#1C8A         ; Throw 'Nonsense in BASIC' if it is

; The following code converts a numerical expression in the DATA statement
; to a string. Thus it is possible to READ a number into a string variable,
; which is a common mistake made in BASICODE programs. We'll tolerate it by
; calling STR$ to convert the number to a string so we can READ it.

       RST    #28             ; Enter calculator
       DEFB   #2E             ; STR$ operation
       DEFB   #38             ; end-calc
READ_N CALL   LET             ; Call LET to assign the value to the variable
       RST    #18             ; Get pointer to current DATA item again
       LD     (23639),HL      ; Save this in DATADD
       LD     HL,(23647)      ; Pick up pointer in X_PTR to READ statement
       LD     (IY+38),#00     ; Clear X_PTR-hi
       LD     (23645),HL      ; Restore CH_ADD pointer to READ statement
READ_2 RST    #18             ; Test if we're currently on a ',' character;
       CP     #2C             ; loop back if there are more variables
       JR     Z,READ_3        ; to be READ
       RET                    ; Done.

; ---------------------------
; The RESTORE command handler
; ---------------------------

RESTORE
       CALL   #1E99           ; Get line number after RESTORE or 0 in BC
REST_RUN                      ; Note: BASICODE does NOT allow a line number!
       CALL   LN_ADDR         ; Find address of line in HL
       DEC    HL
       LD     (23639),HL      ; Set DATADD to location before that
       RET                    ; Done

; -----------------------
; The RUN command handler
; -----------------------
; This calls the ROM handler to set NEWPPC and NSPPC, then calls RESTORE above
; and finally jumps into the CLEAR handler below

RUN    CALL   #1E67           ; Call GO-TO in the ROM to set NEWPPC and NSPPC
       LD     BC,#0000        ; Also do a RESTORE 0
       CALL   REST_RUN
       JR     CL_RUN          ; Jump into CLEAR below

; -------------------------
; The CLEAR command handler
; -------------------------
; In BASICODE, CLEAR accepts two parameters (which may both be defaulted).
; The full syntax is: CLEAR [new RAMTOP],[string space]
; [String space] deserves an explanation. The upper part of memory, which
; expands downwards, is laid out as follows:
;
;        <-------- <----------       <-STRPTR 
; ------+---------+-----------+-----+--------+-----+---------+
; Spare | Machine | FOR/GOSUB | $00 | String | $3E | Machine |
;       |  stack  |   stack   |     | space  |     |  code   |
; ------+---------+-----------+-----+--------+-----+---------+
;                 ^              ^              ^
;                 SP            STRS          RAMTOP
;
; The new area 'String space' is used to store the content of string variables;
; their entries in the VARS area only contain a pointer to it. 
; The String space has a fixed size, set by the second parameter in a CLEAR
; statement. The running pointer STRPTR runs downwards as more strings are
; added to it, until it hits the bottom pointed to by STRS. At this point, the
; Garbage collect routine is called which attempts to clean up the area by
; removing any strings not being pointed to by variables. If, after this
; procedure, there is still insufficient string space available then the error
; 'S Out of string space' is thrown and you should increase the string space.
; This way of manipulating strings using pointers (as opposed to storing them
; literally in the variables area) reduces a lot of time-consuming shuffling of
; bytes in the VARS area. It has its disadvantage in that you have to guess how
; much space you will need for all strings together (not counting literal
; strings in the program). BASICODE caters for this by letting the application
; program specify the amount of space in the variable A before it jumps to the
; initialisation code at line 20.

CLEAR  CALL   SET_PPC         ; Prepare for a shadow ROM return (CLEAR #)
CL_RUN RST    #18             ; Get current character
       CALL   #2048           ; Are we at the end of the statement?
       LD     BC,(23730)      ; Pre-fetch RAMTOP
       JR     Z,CLR_1         ; Jump if we are indeed at the end
       CP     ","             ; Is the next character a comma?
       JR     Z,CLR_1         ; Yes, jump
       CALL   EX_1NUM         ; Evaluate the new RAMTOP value
       CALL   #1E99           ; Fetch it into BC
CLR_1  PUSH   BC              ; Save new RAMTOP
       RST    #18             ; Get current character
       CP     ","             ; Is it a comma?
       CALL   Z,#0020         ; If yes, skip it
       LD     HL,100          ; Load HL with default string space of 100
       CALL   #2048           ; At the end of the statement?
       JR     Z,CLR_2         ; Yes, jump
       CALL   EX_1NUM         ; Evaluate string space argument
       CALL   #1E99           ; Fetch it into BC
       LD     H,B             ; Transfer to HL
       LD     L,C
CLR_2  EX     (SP),HL         ; Exchange new RAMTOP and string space
       PUSH   HL              ; Save RAMTOP again
       LD     DE,(23627)      ; VARS
       LD     HL,(23641)      ; E_LINE
       DEC    HL              ; Leave VARS end marker
       CALL   #19E5           ; Reclaim VARS area
       CALL   #0D6B           ; Do CLS
       LD     HL,(23653)      ; STKEND
       LD     DE,50           ; Take a margin of 50 bytes above STKEND
       ADD    HL,DE
       LD     B,H             ; Copy to BC
       LD     C,L
       POP    DE              ; Retrieve new RAMTOP
       SBC    HL,DE           ; New RAMTOP must be above STKEND + margin
       JP     NC,#1EDA        ; Else report 'RAMTOP no good'
       LD     HL,(23732)      ; P_RAMT, end of physical RAM
       AND    A               ; Compare against new RAMTOP; throw error if new
       SBC    HL,DE           ; RAMTOP would be above P_RAMT (unlikely to
       JP     C,#1EDA         ; happen on a 48K machine...)
       EX     DE,HL           ; new RAMTOP goes to HL
       POP    DE              ; Retrieve string space
       PUSH   HL              ; Save new RAMTOP again
       SBC    HL,DE           ; Decrease RAMTOP by string space requested
       JR     C,RPRT_S        ; Error if this comes out negative (can happen?)
       SBC    HL,BC           ; Now compare to STKEND + margin
       ADD    HL,BC
RPRT_S JP     C,#1F15         ; If they clash, report 'Out of memory'
       LD     (STRS),HL       ; This is stored in the variable STRS
       LD     (HL),#00        ; The bottom marker for the new FOR/GOSUB stack
       POP    DE              ; Retrieve new RAMTOP
       LD     (23730),DE      ; Store it in the system variable
       LD     (STRPTR),DE     ; Also, set STRPTR (it will run downwards)
       POP    DE              ; Pop return address to STMT_RET
       POP    BC              ; This is the error return - usually MAIN_4
       LD     SP,HL           ; Bottom of new machine stack
       PUSH   BC              ; Push error return handler
       LD     (23613),SP      ; and set ERR_SP
       EX     DE,HL           ; Return address STMT_RET to HL
       JP     (HL)            ; and exit by jumping to it

; -----------------------------------
; The GOTO and GOSUB command handlers
; -----------------------------------
; There is no ON..GOTO/GOSUB command in ZX Basic. They will take expressions as
; arguments, which by itself is a powerful feature, but in BASICODE only
; literal arguments are allowed. If you want to take different branches as
; result of an expression, you should use ON expr GOTO/GOSUB l1,l2,l3,..
; where l1 is taken if expr evaluates to 1, l2 if expr = 2, and so on.
; In BASICODE, expr must not exceed the number of branches given so expr = 4
; would be illegal when there are only 3 branches. In reality, most BASICS
; then simply continue at the next statement without branching. And indeed,
; many BASICODE programmers did just assume that :-(.
; To implement ON..GOTO/GOSUB, we use GOTO/GOSUB with a special syntax:
;
;   GOTO/GOSUB *expression;line1,line2,line3...
;
; Thus expression=1 does a GOTO or GOSUB to line1, expression=2 to line2,
; and so on. There is no limit on the number of branches except for the line
; length, which in BASICODE is just 60 characters...

; The entry point GOTO is jumped to from the main statement loop, and also
; called from GOSUB. The carry flag is returned set if the expression in the
; ON syntax successfully matched a line number specified.

GOTO   CP     "*"             ; Is current character a '*'?
       JR     Z,ON            ; Yes, handle ON..GOTO/GOSUB
       CALL   EX_1NUM         ; Else, evaluate a single line number
       JP     #1E67           ; Jump to the ROM's GOTO handler (this will
                              ; return carry set)
; Handle ON syntax

ON     RST    #20             ; Skip-over the '*'
       CALL   EX_1NUM         ; Evaluate the expression
       CP     ";"             ; It must be followed by a semicolon
       JP     NZ,#1C8A        ; report 'Nonsense in BASIC' otherwise
       CALL   #1E94           ; Get result of expression in A

; Now loop for a matching line number 'A' times

ON_LP  PUSH   AF              ; Save the counter
       RST    #20             ; Next character
       CALL   EX_1NUM         ; Evaluate the line number
       CALL   #1E99           ; This goes to BC
       POP    AF              ; retrieve counter
       DEC    A               ; Decrement it (it should be in range 1-255)
       JP     Z,#1E6A         ; If it reaches zero, exit setting NEWPPC/NSPPC
       LD     C,A             ; Save the counter briefly
       RST    #18             ; Consider current character
       CP     ","             ; Is it a comma?
       LD     A,C             ; Restore counter
       JR     Z,ON_LP         ; Loop back for next line number
       AND    A               ; Else, signal 'no matching line number found'
       RET                    ; Done

; GOSUB first calls GOTO to evaluate the destination (this handles ON too).
; If there is a valid destination, the following data is pushed onto the GOSUB
; stack:
;
; Byte  0  : $ED (GOSUB marker)
; Byte  1  : Statement number after GOSUB
; Bytes 2-3: Line number of GOSUB statement
; Bytes 4-5: Offset of statement after GOSUB, relative to PROG/E_LINE

GOSUB  CALL   GOTO            ; Carry flag will be set with a valid destination
       RET    NC              ; Else, exit and continue with next statement
       RST    #18             ; Get current character
       CALL   #2048           ; Have we reached the end of the statement?
       LD     DE,#0200        ; Set D to 2 for 'next statement'
       CALL   NZ,#198B        ; If not at the end, skipover any excess
                              ; characters (in case of ON..GOSUB).
       POP    DE              ; Pop return address STMT_RET
       CALL   STMTAD          ; Get offset to PROG/E_LINE in HL
       EX     (SP),HL         ; Exchange this with error return address
       LD     BC,(23621)      ; Now push current line number on the stack
       PUSH   BC
       LD     B,(IY+13)       ; Include statement number (second byte)
       LD     C,#ED           ; and the marker (first byte)
       PUSH   BC
       PUSH   HL              ; Push error return address again
       LD     (23613),SP      ; and set ERR_SP
       PUSH   DE              ; Finally push STMT_RET again
       JP     #1F02           ; Exit to test if enough memory available

; RETURN works the opposite way - it gets the destination from the GOSUB stack
; Note that unfinished FOR-NEXT loops in the subroutine are also reclaimed!

RETURN LD     HL,4            ; Skipover statement and error return addresses
       ADD    HL,SP
RET_LP LD     A,(HL)          ; Test the marker byte of the top stack entry
       AND    A               ; A zero marks the bottom of the stack -
       JP     Z,#1F38         ; throw 'RETURN without GOSUB'
       CP     #ED             ; Is it the GOSUB marker?
       JR     Z,RET_FND       ; Yes, jump forward
       LD     DE,18           ; Else, it must be a FOR entry - skip 18 bytes
       ADD    HL,DE
       JR     RET_LP          ; loop back

; A return address has been found - set the relevant system variables and
; clean up the stack

RET_FN INC    HL              ; Point to statement #, line #, and offset
       PUSH   HL              ; Save pointer
       CALL   JUMP            ; Set the relevant system variables
       POP    HL              ; Retrieve pointer
       LD     DE,5            ; Skip 5 bytes to next entry
       ADD    HL,DE
       POP    DE              ; Pop STMT_RET
       POP    BC              ; and error return
       LD     SP,HL           ; Set new machine stack pointer
       PUSH   BC              ; Save error return again
       LD     (23613),SP      ; and set ERR_SP
       EX     DE,HL           ; STMT_RET goes to HL
       JP     (HL)            ; and exit by jumping to it

; --------------------------
; The DEF FN command handler
; --------------------------
; DEF FN is handled very differently from the ROM. FNs are stored as variables
; in the VARS area. Thus, the DEF FN statement has to be actually executed for
; a function to be recognised.
;
; The format of a function in the VARS area is as follows:
;
; +------+---+--------+--------+------+-----+--------+--------+
; | name | 0 | len-lo | len-hi | args | 80h | ptr-lo | ptr-hi |
; +------+---+--------+--------+------+-----+--------+--------+
;
; name has bit 7 set, bit 6 is set for a numeric function and reset for a
; string function. The name can have max 255 chars and is null terminated.
; args is a local variable storage (terminated by 80h).
; ptr is pointer to the function definition, relative to PROG.
;
; Note that LEFT$, MID$ and RIGHT$ are also implemented as FN functions.

DEF_FN BIT    7,(IY+12)       ; The DEF FN cannot be in a direct command
       JR     Z,DEFFN1
       CALL   ERROR           ; else, throw report 'T Illegal direct'
       DEFB   #1C
DEFFN1 LD     C,#80           ; Set bit 7 for FN functions
       LD     (23647),HL      ; Save CH_ADD temporarily in X_PTR
       CALL   LOOKV1          ; Look for the name in the VARS area
       JP     NZ,#1C8A        ; It must be followed by a '('
       LD     C,B             ; Copy the length of the name to C
       LD     B,#00           ; Now BC = length of name
       JR     C,DEFFN2        ; Jump if there is an existing FN with same name
       PUSH   BC              ; Save length
       SBC    HL,BC           ; Point to start of existing FN
       PUSH   HL              ; Save pointer
       CALL   NEXT_ONE        ; Find next variable in HL
       POP    DE              ; Retrieve pointer to existing FN
       CALL   #19E5           ; Call RECLAIM to remove it
       POP    BC              ; Retrieve BC
DEFFN2 PUSH   BC              ; Save length of name
       INC    BC              ; Increment by three for the null terminator and
       INC    BC              ; two length bytes
       INC    BC
       RST    #30             ; Allocate this space in WORKSP
       LD     HL,(23647)      ; Retrieve CH_ADD
       LD     A,(HL)          ; Get first letter of name
       AND    #1F             ; Keep only bits 0 to 4
       LD     C,A             ; Copy this to C
       LD     A,(23611)       ; Fetch FLAGS (bit 6 is 0 for string, 1 numeric)
       AND    #C0             ; Keep bits 6 and 7 (bit 7 will always be 1)
       OR     C               ; Mask in bits 0-4 of first letter

; A loop is entered to copy the function's name into the workspace

DEFFN3 LD     (DE),A          ; Store a character
       INC    DE              ; Advance pointer
       CALL   #28AB           ; Call FN-SKPOVR to get next non-space character
       CALL   #2C88           ; Test next character for alphanumeric code
       SET    5,A             ; Make any subsequent character lowercase
       JR     C,DEFFN3        ; Loop as long as it's alphanumeric
       XOR    A               ; Terminate the name with a null byte
       LD     (DE),A
       RST    #20             ; Advance to next character
       CP     ")"             ; A closing bracket indicates no parameters -
       JR     Z,DEFFN4        ; jump forward

; The following loop parses the formal parameters of the function, creating
; space in WORKSP for them as we go

PRM_LP CALL   #2C8D           ; The first letter must be alphabetic
       JP     NC,#1C8A        ; else give 'Nonsense in BASIC'
       LD     BC,#0001        ; One extra space
       RST    #30
       PUSH   DE              ; Save pointer
PRM_CH OR     #20             ; Convert to lowercase
       LD     (DE),A          ; Enter character
       RST    #30             ; Make another space
       RST    #20             ; Skip to next character
       CALL   #2C88           ; Loop as long as it's alphanumeric
       JR     C,PRM_CH
       EX     DE,HL           ; Destination address goes to HL
       LD     (HL),#00        ; Terminate the name with a null byte
       POP    HL              ; Retrieve pointer to first character
       CP     "$"             ; Is it a string parameter?
       JR     NZ,DEFSPC       ; No, skip
       RES    6,(HL)          ; Else, clear bit 6 of first character to
       RST    #20             ; indicate a string and skip the '$' character
DEFSPC LD     BC,#0005        ; Now make 5 spaces for the value of the argument
       RST    #30             ; which will be filled in when the FN is called
       RST    #18
       CP     ","             ; Are we on a comma?
       JR     NZ,DEF_BR       ; No, skip
       RST    #20             ; Else, skip the comma and loop back for another
       JR     PRM_LP          ; parameter
DEF_BR CP     ")"             ; The parameter list must be terminated by a
DEFFN4 JP     NZ,#1C8A        ; closing bracket, else give 'Nonsense in BASIC'
       RST    #20             ; Next character
       CP     "="             ; .. which must be an equals sign
       JR     NZ,DEFFN4       ; .. else report 'Nonsense in BASIC'
       RST    #20             ; Advance to start of FN's expression
       LD     DE,(23635)
       SBC    HL,DE           ; Make the pointer relative to PROG
       PUSH   HL              ; Save it for later
       LD     BC,#0003        ; Three spaces are needed for the pointer and the
       RST    #30             ; $80 end marker for the FN's arguments
       EX     DE,HL           ; The pointer to this space goes to HL
       POP    DE              ; Retrieve offset of expression to PROG
       LD     (HL),#80        ; Enter the $80 end marker
       INC    HL
       LD     (HL),E          ; And the pointer to the FN's expression
       INC    HL
       LD     (HL),D
       INC    HL              ; Point past last byte of space created
       LD     DE,(23649)      ; Start of WORKSP
       AND    A
       SBC    HL,DE           ; Find the length in HL
       PUSH   HL              ; Save it and copy to BC
       LD     B,H
       LD     C,L
       LD     HL,(23641)      ; E_LINE
       DEC    HL              ; Point to last byte of VARS area
       CALL   #1655           ; Now make the required space
       POP    BC              ; Get a copy of the length
       PUSH   BC
       LD     HL,(23651)      ; STKBOT
       DEC    HL              ; Point to last byte in WORKSP
       LDDR                   ; Now copy over the FN's definition to VARS
       EX     DE,HL
       INC    HL              ; Now HL points to first byte of FN in VARS
       POP    DE              ; Retrieve length of space
       POP    BC              ; Retrieve length of name
       ADD    HL,BC           ; Skip to end of name
       INC    HL              ; .. and terminating null byte
       EX     DE,HL           ; Length of space to HL
       SCF                    ; The length of the name plus null byte should
       SBC    HL,BC           ; be discounted from the total length
       DEC    HL              ; Also discount the two length bytes themselves
       DEC    HL
       EX     DE,HL           ; Swap length with pointer
       LD     (HL),E          ; Enter reduced length after name
       INC    HL
       LD     (HL),D
       RST    #18             ; Get pointer to current character
       LD     DE,#0200        ; Signal 'skip to next statement'
       JP     #198B           ; .. and exit via EACH-STMT

; ------------------------------------
; The PRINT and LPRINT command handler
; ------------------------------------
; These work similar to the ROM's handlers except that our own expression
; evaluator is called.

LPRINT LD     A,#03           ; LPRINT entry point; use stream #3
       JR     PRINT1
PRINT  LD     A,#02           ; PRINT entry point; use stream #2
PRINT1 CALL   #1601           ; Select this stream
       CALL   #0D4D           ; Set temporary colours

; The following subroutine is also called from INPUT when there is a prompt
; in braces, e.g. INPUT (A$);IN$. A$ is then treated as an expression to be
; printed as prompt. This is strictly NOT allowed in BASICODE!

PRINT2 RST    #18             ; Get current character
       CALL   #2045           ; Any more to print?
       JR     Z,PRINT4        ; No, exit
PRINT3 CALL   #204E           ; Consider any positional characters (; , ')
       JR     Z,PRINT3        ; Loop back for next item
       CALL   PR_ITEM         ; Now print next item
       CALL   #204E           ; Consider more positional characters
       JR     Z,PRINT3        ; Loop back for next
       CALL   #2045           ; Any more items?
       JR     NZ,PRINT3       ; Yes, loop back
PRINT4 CP     #29             ; End of loop, return when dealing with ")"..
       RET    Z               ; .. in an INPUT prompt
PR_CR  LD     A,#0D           ; Else, print a final CR at the end of a PRINT
       RST    #10             ; statement (#204E drops out of the loop early)
       RET

; Print a single item. Equivalent to PR-ITEM-1 in the ROM except it calls our
; own expression evaluator

PR_ITEM
       RST    #18             ; Get current character
       CP     #AC             ; Is it 'AT'?
       JR     NZ,PR_I2        ; No, skip
       CALL   NXT_2NUM        ; Get AT arguments
       JP     #2007           ; Leave the rest to the ROM
PR_I2  CP     #AD             ; Is it 'TAB'?
       JR     NZ,PR_I3        ; No, skip
       RST    #20             ; Advance to next character
       CALL   EX_1NUM         ; Get TAB argument
       JP     #2019           ; Leave the rest to the ROM
PR_I3  CALL   CO_T3           ; Handle any colour items
       RET    NC              ; Return if success
       CALL   STR_ALT         ; Consider any '#stream' items
       RET    NC              ; Return if dealt with it
       CALL   SCANNING        ; Call the expression evaluator for anything else
       JP     #2032           ; and jump into the ROM to do actual PRINTing

; Consider '#stream' in PRINT or INPUT
; Returns carry reset if such an item has been handled

STR_ALT
       CP     #23             ; Is the current character a '#'?
       SCF
       RET    NZ              ; If not, return carry set
       RST    #20             ; Advance to next character
       CALL   EX_1NUM         ; Evaluate the number after '#'
       JP     #207C           ; Jump to the ROM to finish handling

; -------------------------
; The INPUT command handler
; -------------------------
; INPUT is handled slightly different from the ROM. BASICODE expects an input
; prompt to appear at the current PRINT position, hence in the upper part of
; the screen. To facilitate this, we use default stream #2 which calls an input
; routine in our 42-column screen driver. This prints a flashing cursor at the
; current position while waiting for a keypress.
; Note: BASICODE-3 is much more restrictive about INPUT prompts. The original
; protocol did not allow a prompt string, in the second edition a single string
; (like INPUT "Your name:";A$) was allowed. This implementation still allows
; expressions as prompt when enclosed in braces (as in ZX BASIC); however in
; BASICODE this is NOT allowed.

INPUT  LD     A,#02           ; Select default stream #2 (channel 'S')
       CALL   #1601
IN_IT1 CALL   #204E           ; Consider positional delimiters
       JR     Z,IN_IT1
       CP     "("             ; Is the current character '('?
       JR     NZ,IN_IT2       ; No, skip
       RST    #20             ; Advance pointer
       CALL   PRINT2          ; Handle expression enclosed in braces
       RST    #18
       CP     ")"             ; Check for closing ')'
       JP     NZ,#1C8A        ; Else report 'Nonsense in BASIC'
       RST    #20             ; Advance pointer
       JP     IN_NX2          ; Jump to end of loop

; At this point either a variable name or a PRINTable item must follow.

IN_IT2 CALL   #2C8D           ; Is the current character alphanumeric?
       JP     NC,IN_NX1       ; No, skip
       CALL   CL01            ; Call CLASS-01 handler to consider variable
       LD     HL,(23645)      ; Save CH-ADD
       PUSH   HL
       JR     IN_SAV          ; Jump forward

; This code handles syntax errors when dealing with numeric input. 
; A message 'INPUT ERROR; REENTER' is printed and the flow loops back to the
; input handler.

IN_BAD SET    6,(IY+1)        ; Signal 'numeric result to be expected'
                              ; (A string input cannot have syntax errors)
       LD     (IY+0),#FF      ; Clear any error
       LD     (IY+82),#03     ; Reset scroll counter to avoid the 'scroll?'
       XOR    A               ; prompt being printed before the message
       LD     DE,IN_MSG
       CALL   #0C0A           ; Call PO-MSG to print the message
       POP    HL              ; Retrieve original error handler
       LD     (23613),HL

; The input handler proper enters here

IN_SAV LD     HL,(23613)      ; Save current error handler
       PUSH   HL
       LD     HL,IN_BAD       ; Make IN_BAD the new error handler
       PUSH   HL
       CALL   #16BF           ; Clear WORKSP
       LD     (IY+82),#02     ; Reset scroll counter

; A loop is now entered to fetch each character in turn. When INPUTing from
; channel 'S' (the default), the DELETE key ($7F) is also considered.

IN_ED  CALL   #15DE           ; Call WAIT-KEY1 to fetch a character
       LD     C,A             ; Save the code in C
       SCF                    ; Preset the carry flag
       LD     A,(BRKFLG)      ; Consider the BREAK flag; if this is set to 1
       DEC    A               ; then call BREAK-KEY to test the BREAK status,
       CALL   NZ,#1F54        ; else don't test it
       JP     NC,#0D00        ; Report 'BREAK - CONT repeats' if BREAK pressed
       LD     A,C             ; Restore character code
       CP     #0D             ; Is it 'ENTER' (EOL code)?
       JR     Z,IN_SP         ; Yes, jump
       CALL   IN_CHAN_S       ; Are we dealing with channel 'S' (screen)?
       JR     NZ,IN_SP        ; If not, jump to store it

;; NOTE: Jump could be one instruction further as the flags are preserved so
;; IN_CHAN_S doesn't have to be called again!

       CP     #20             ; Reject any control characters
       JR     C,IN_ED
       CP     #7F             ; This is the code for DELETE from the 42-column
       JR     NZ,IN_SP        ; channel 'S' driver
       LD     HL,(23651)      ; STKBOT
       LD     DE,(23649)      ; WORKSP
       DEC    HL              ; Step one byte down
       SBC    HL,DE           ; An empty workspace will now set the carry flag
       ADD    HL,DE           ; Restore HL
       JR     C,IN_ED         ; Loop back if input line is already empty 
       LD     BC,1            ; Else, reclaim one byte
       CALL   #19E8
       LD     A,#7F           ; Now print the DELETE character - the 42-column
       RST    #10             ; driver will rub out the previous character
       JR     IN_ED           ; Loop back

; It's time to store the newly fetched character

IN_SP  CALL   IN_CHAN_S       ; Are we INPUTing from the screen?
       PUSH   AF              ; Save A
       CALL   Z,#0010         ; If yes, echo the character on the screen
       POP    AF              ; Retrieve A
       LD     BC,1            ; Make one space in the workspace
       RST    #30
       LD     (DE),A          ; Enter the character
       CP     #0D             ; Loop back unless it was ENTER/EOL
       JR     NZ,IN_ED
       BIT    6,(IY+1)        ; Test the numeric/string flag
       JR     Z,IN_STR        ; Jump with string input
       CALL   IN_CHAN_S       ; Dealing with screen input?
       JR     NZ,IN_WORK      ; No, skip
       LD     (23613),SP      ; Else, set error handler

; A numeric input is to be parsed. We call EX_1NUM to effectively evaluate it;
; thus it may be any valid numeric expression. Syntax errors are only trapped
; when INPUTing from channel 'S' and will come back to IN_BAD which prints an
; error message on the screen.

IN_WOR LD     HL,(23649)      ; Set CH-ADD to start of WORKSP
       LD     (23645),HL
       CALL   EX_1NUM         ; Now evaluate it as a numeric expression
       CP     #0D             ; Check if the end has been reached
       JR     Z,IN_ASSIGN     ; Go assigning if it has
       RST    8               ; If not, throw 'Nonsense in BASIC'
       DEFB   #0B

; When dealing with string input, simply stack the string parameters.

IN_STR LD     HL,(23651)      ; STKBOT
       LD     DE,(23649)      ; WORKSP, also start of string
       SCF                    ; Exclude the terminating CR
       SBC    HL,DE           ; Form the length of the string in HL
       LD     B,H             ; Transfer to BC
       LD     C,L
       CALL   #2AB2           ; Now stack the parameters
IN_ASS POP    HL              ; Drop the IN_BAD error handler
       POP    HL              ; Restore normal error handler
       LD     (23613),HL
       POP    HL              ; Restore original CH-ADD
       LD     (23645),HL
       CALL   LET             ; Now call LET to do the assignment
       JR     IN_NX2          ; Skip to next item

;; NOTE:There is a remote possibility that the original location of CH-ADD has
;; been moved during the INPUT process. This can happen when Interface 1 is 
;; attached but the extended system variables haven't been created yet, and
;; a syntax error occurs during parsing of a numeric input. The latter will
;; create the extended system variables, thereby moving up the program, but
;; CH-ADD will be restored to the original location and 'lose its place'.
;; This is very likely to generate a 'Nonsense in BASIC' error after completion
;; of the INPUT command. The ROM's INPUT handler suffers from the same bug.

; The following target handles any PRINTable items in the INPUT statement;
; these include '#stream' to change the default stream in case of reading from
; a storage medium (usually from GOSUB 540).

IN_NX1 CALL   PR_ITEM         ; Call PR_ITEM to handle the PRINTable item
IN_NX2 CALL   #204E           ; Loop back as long as there are more items
       JP     Z,IN_IT1
       RET                    ; Else, done with INPUT.

; This routine is called on three occasions to check if INPUT is dealing with
; channel 'S', i.e. the screen. If so, the zero flag is returned set.

IN_CHAN_S
       LD     C,A             ; Save A in C
       LD     HL,(23633)      ; Get CURCHL
       INC    HL              ; Step past the pointers to the output and input
       INC    HL              ; routines
       INC    HL
       INC    HL
       LD     A,(HL)          ; Get the channel type letter
       CP     "S"             ; An 'S' will set the zero flag
       LD     A,C             ; Restore A
       RET                    ; Done

; The following message is printed if a numeric input contains a syntax error.

IN_MSG DEFB   #80             ; Marker byte required for PO-MSG
       DEFM   "INPUT ERROR; REENTER"
       DEFB   #8D             ; The message is terminated by CR with bit 7 set

; -------------------
; Colour Item Handler
; -------------------
; These routines are called from the Class 07, Class 09 and PR_ITEM routines.
; Similar to ROM CO-TEMP-x handlers, except for the call to EX_1NUM.

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

; --------------------------
; The CIRCLE command handler
; --------------------------
; A simple call to EX_1NUM for the 3rd argument, then jumps to the ROM handler.
; Not used by BASICODE programs, though there used to be 'future plans' to
; incorporate it in a new standard subroutine...

CIRCLE RST    #18
       CP     ","
       JR     NZ,CO_RPC
       RST    #20
       CALL   EX_1NUM
       JP     #232D

; ----------------------------------
; The PLOT and DRAW command handlers
; ----------------------------------
; This version allows PLOTting and DRAWing on the lower two rows of the screen,
; thus the Y parameter range is 0 to 191 rather than 0 to 175. This way, we can
; keep the aspect ratio at 4:3 while using the whole screen area for graphics.
; I had to partially rewrite the PLOT and DRAW routine proper to accomodate
; this, and it's still not fully implemented - only PLOT and DRAW with two 
; arguments support this extended range (which is sufficient for the BASICODE-3
; graphics subroutines fortunately!)

PLOT   CALL   #2307           ; PLOT: call STK-TO-BC to get the arguments in BC
       CALL   PL_SUB          ; Do the actual PLOT
       JP     #0D4D           ; Exit, restoring any permanent colours.

; This subroutine does the actual PLOTting.

PL_SUB LD     (23677),BC      ; Set COORDS
       LD     A,#BF           ; Call the PIXEL-ADD routine but this time the
       CALL   #22AC           ; upper pixel row has number 191 rather than 175
       JP     #22EC           ; Leave the rest to the ROM.

DRAW   RST    #18             ; DRAW enters here, check for a 3rd argument
       CP     ","
       JR     NZ,LN_DRAW      ; Jump if only 2 arguments

; These 3 lines handle DRAW with 3 arguments, for drawing an arc. This is not
; implemented in BASICODE and doesn't support the extended 256x192 range.

       RST    #20             ; Advance past the ','
       CALL   EX_1NUM         ; Evaluate the 3rd (arc) argument
       JP     #2394           ; Leave it up to the ROM

; Draw a straight line - 256x192 supported.
; Again, taken from the ROM code except for the call to PL_SUB.

LN_DRA CALL   #2307           ; STK-TO-BC
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

; ------------------------
; The EXPRESSION EVALUATOR
; ------------------------
; And this is where the magic starts...
; This is the subroutine which evaluates any expression, numeric or string, and
; produces a result on the calculator stack. The expression may be as simple as
; a single number or variable or as complex as 'CHR$(T+A-26*INT((T+A)/26)+65)'
; (or even more complex!). 
; The Spectrum's BASIC is much praised for its powerful mathematic and string
; handling functions. However, a number of limitations, which are presumably a
; left-over of its memory-cramped predecessors ZX80 and ZX81, hamper its
; capability to run BASICODE programs:
;
; - The names of string and array variables are confined to just one letter.
; - Strings in string arrays have static length. This is the final dimension
;   of a string array in a DIM statement. If you assign a longer string to a
;   string array element, the excess gets chopped off. If you assign a shorter
;   string, it gets padded with spaces ('Procrustean lengthening').
; - Arrays cannot have a subscript 0, whereas in BASICODE they can.
; - String slicing functions LEFT$, MID$ and RIGHT$ are missing. There is an
;   excellent substitute in the form A$(X TO Y), and with DEF FN you can even
;   make the conversion fairly automatic; e.g. DEF FN L$(A$,N)=A$(TO N) and
;   replace all occurrences of LEFT$(..) with FN L$(..).
;   However, in ZX BASIC, the use of a subscript (X TO Y) (where both X and Y
;   may be left out as well as 'TO') for string slicing leads to confusion 
;   with string array subscripts. Indeed, in ZX BASIC, string arrays and simple
;   strings share the same name space, whereas in BASICODE you can happily have
;   a simple string A$ and a string array A$() without confusion.
;
;   Let's do this in BASICODE:
;     DIM A$(10)
;     LET A$="simple string"
;     LET A$(1)="array string"
;     then PRINT A$,A$(1) will print "simple string  array string"
;   But in ZX BASIC it will print:   "aimple string  a"
;   So ZX BASIC treats A$(1) as the first letter of fixed-length string A$!
;   (it will even get more complicated with multi-dimensional string arrays...)
;   In the end, to stop this confusion, I decided to drop ZX BASIC's string
;   slicing altogether. This might be seen as a great loss, but remember that
;   the goal to write this interpreter extension was not to make the Spectrum's
;   BASIC better, but to make it BASICODE compatible...
;
;   Of course, the upshot of all this is that I had to rewrite almost the
;   ENTIRE expression evaluator, including a new design for variable storage!

SCANNING
       RST    #18             ; Get current character
       LD     B,#00           ; The machine stack will hold a hierarchy of
       PUSH   BC              ; operations and priorities to be performed;
                              ; a zero in B signifies the bottom of it.
S_LP1  LD     C,A             ; Character code to C
       LD     HL,SF_TABLE     ; This table holds a subset of functions
       CALL   #16DC           ; Lookup character code in the table
       LD     A,C             ; Restore A
       JP     NC,S_ALPNUM     ; If not found, jump forward
       LD     B,#00           ; Else, find offset in BC
       LD     C,(HL)
       ADD    HL,BC           ; Form address of handler in HL
       JP     (HL)            ; and jump to it

; This subroutine handles functions requiring two arguments in brackets,
; such as SCREEN$, ATTR and POINT.

S_2COORD
       RST    #20             ; Get next character
       CP     "("             ; Must be opening bracket,
       JR     NZ,S_RPC        ; else 'Nonsense in BASIC'
       CALL   NXT_2NUM        ; Evaluate two numeric arguments
       RST    #18             ; Get character after the arguments
       CP     ")"             ; Must be closing bracket
S_RPC  JP     NZ,#1C8A        ; else 'Nonsense in BASIC'
       RET                    ; Done

; This table contains handlers for the following expression items:
; - Literal strings in double quotes
; - Sub-expressions in brackets
; - Literal numbers starting with decimal point '.'
; - Literal binary numbers, e.g. 'BIN 10010101'
; - Unary plus
; - User functions 'FN x(..)'
; - Functions RND, INKEY$, PI, SCREEN$, ATTR and POINT

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
       RST    #20             ; Unary plus, just skip it and loop back
       JP     S_LP1

S_QUOTE
       RST    #18             ; (Double) Quote character
       INC    HL              ; Step past opening quote
       PUSH   HL              ; Save this address
       LD     BC,#0000        ; Initialise length
       CALL   #250F           ; Call S-QUOTE-S to count characters
       DEC    BC              ; Discount closing quote
       POP    DE              ; Get start address of string in DE

; Note: This routine doesn't support quote characters in literal strings,
; unlike the ROM. In BASICODE, they're not allowed anyway.

; The next entry point stacks string parameters. The registers should be set as
; follows and are stacked in order A, E, D, C, B on the calculator stack:
; A : flag to indicate absolute (0) or relative (1) address in DE
; BC: Length of string
; DE: Address of string; either absolute (A=0) or relative to PROG if A=1.

S_STRING
       CALL   #2AB2           ; Stack the parameters (also resets FLAGS bit 6)
       JP     CONT2           ; Jump forward to continue scanning

S_BRACKET
       RST    #20             ; An expression in brackets will be evaluated..
       CALL   SCANNING        ; .. by calling SCANNING recursively
       CP     ")"             ; .. and must be followed by a closing bracket
       JP     NZ,#1C8A        ; .. else, report 'Nonsense in BASIC'.
       RST    #20             ; Step past closing bracket
       JP     CONT2           ; And jump forward to continue scanning

S_FN   JP     SF_SUB          ; User defined function 'FN'; jump forward

S_RND  LD     BC,(23670)      ; RND handler
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
S_PI   RST    #28             ; PI handler
       DEFB   #A3,#38         ; stk-pi/2
       INC    (HL)            ; Double to PI by incrementing the exponent
S_PI_END
       RST    #20             ; Skip past keyword
       JP     S_NUMERIC       ; Jump to signal 'numeric result'

S_INK$ LD     BC,#105A        ; INKEY$ handler
       RST    #20
       CP     "#"             ; consider INKEY$#stream
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

S_SCR$ CALL   S_2COORD        ; SCREEN$ handler
       CALL   SCREEN$         ; real handler is in BCFN.ASM and vectored
       RST    #20
       JR     S_STR

S_ATTR CALL   S_2COORD        ; ATTR handler
       CALL   #2580
       RST    #20
       JR     S_NUMERIC

S_POINT
       CALL   S_2COORD        ; POINT handler
       CALL   #22CB
       RST    #20
       JR     S_NUMERIC

; Current character was none of the above, now test for alphanumeric codes

S_ALPNUM
       CALL   #2C88           ; Alphanumeric code returns carry set
       JR     NC,NEGATE       ; Jump if not alphanumeric
       CP     #41             ; Is it a letter?
       JR     NC,S_LETTER     ; Yes, jump

S_DEC  CALL   NOTBIN          ; Evaluate decimal literals
       JR     S_BIN1
S_BIN  CALL   #2C9F           ; Handle 'BIN 10010101' form
S_BIN1 LD     HL,(23645)      ; These lines ensure that possible hidden binary
       LD     A,(HL)          ; numbers ($0E followed by 5 bytes) following the
       CALL   #18B6           ; ASCII literals are skipped. They should not
       LD     (23645),HL      ; occur in a program but may occur in direct
       JR     S_NUMERIC       ; commands.

; The following subroutine handles decimal literal numbers. It calls the VAL
; vectors in BCFN.ASM to do the actual evaluation.

NOTBIN CP     "."
       JP     Z,VALSUB        ; Handle the form '.123'
       RST    #18
       PUSH   HL              ; Save current location
       CALL   INT_TO_BC       ; Try evaluating as 16-bit integer first
       CALL   NC,#2D2B        ; If successful, stack it
       POP    HL              ; Restore current location
       JR     NC,DEC_TST      ; Jump if integer part fits into 16 bits
       CALL   #0078           ; Else, reset CH-ADD
       CALL   #2D3B           ; .. and evaluate integer part as floating point
DEC_TST
       RST    #28             ; Invoke calculator
       DEFB   #A1,#C2,#02     ; Store a 1 in MEM-2 (required for VALFRC later)
       DEFB   #38
       LD     HL,(23645)      ; CH-ADD
       LD     A,(HL)
       JP     VALFRC          ; Jump to VALFRC to evaluate any fractional part

S_NUMERIC
       SET    6,(IY+1)        ; A numeric value has been stacked so set bit 6
       JR     CONT2           ; of FLAGS and continue

S_LETTER
       CALL   LOOKVARS        ; If everything else has been excluded, look for
       JR     NC,TST_VAR      ; variables. Jump if one has been found.
       JP     Z,#1C2E         ; 'Variable not found' with undimensioned arrays

; We have encountered an undefined variable. The normal response from ZX BASIC
; was now to throw a 'Variable not found' message, and in BASICODE it is indeed
; a requirement to assign a value to a variable first before using it in an
; expression. Unfortunately, BASICODE was also based on Micro$oft BASIC which
; happily assumes that unassigned variables have a value of 0 or empty string.
; And so, many programmers who either were too lazy or ignorant to read the
; rules simply 'forgot' to set variables first and got away with it.
; In the end, after many 'Variable not found' errors and manual corrections of
; other's failures, I decided to capitulate... So, the following three lines
; were added which stack a zero in place of the missing variable. (Note that
; it could have been done with un-DIM'ed arrays too, but this would be more
; complicated because the subscripts would have to be parsed too).

       RST    #28             ; Invoke the calculator
       DEFB   #A0,#38         ; Stack a zero
       JR     CONT2           ; And here we go again...

; At this point, an existing variable has been identified.

TST_VA CALL   Z,DESTAD        ; Find the actual location of an array element
       INC    HL              
       BIT    6,(IY+1)        ; Test numeric/string flag
       JR     Z,STKSTR        ; Jump with strings
       CALL   #33B4           ; else, call STACK-NUM
       JR     CONT2

; A string has to be stacked. Unlike a numeric value, this is not a simple copy
; operation since the address stored in the variable may be absolute or
; relative to PROG. Stacked string addresses must always be absolute.

STKSTR LD     A,(HL)          ; The absolute or relative flag
       INC    HL
       LD     E,(HL)          ; Address to DE
       INC    HL
       LD     D,(HL)
       INC    HL
       LD     C,(HL)          ; And length to BC
       INC    HL
       LD     B,(HL)
       AND    A               ; Was the address absolute?
       JR     Z,S_STK         ; Yes, go store it
       LD     HL,(23635)      ; Else, it's a literal string in the program area
       ADD    HL,DE           ; so add PROG to it
       EX     DE,HL
S_STK  CALL   #2AB6           ; Stack the parameters
       JR     CONT2

; At this point, a non-alphanumeric operator or function has been identified.
; An operation code is built up in the C register where bits 6 and 7 indicate
; the type of operand (bit 6) and result (bit 7); 0 for string, 1 for numeric.
; This is pushed onto the machine stack together with a priority indicator (in
; the B register) so that the operation can be performed after evaluation of
; the operand.

NEGATE LD     BC,#09DB        ; Negate; priority 9, code 1B (numeric, numeric)
       CP     "-"             ; Is current character a '-'?
       JR     Z,S_PUSHPO      ; Yes, jump
       SUB    #AF             ; Subtract $AF for 'CODE' and higher
       JP     C,#1C8A         ; Everything below gives 'Nonsense in BASIC'

; Note: VAL$ has been removed here!

       LD     BC,#04F0        ; Priority 4, code $30 (numeric, numeric)
       CP     #14             ; Compare against 'NOT'
       JR     Z,S_PUSHPO      ; Jump with 'NOT'
       JP     NC,#1C8A        ; Throw 'Nonsense in BASIC' with higher codes
       LD     B,#10           ; Remaining functions have priority 16
       ADD    A,#DC           ; Now the range is $1C to $2F with bits 6 and 7
       LD     C,A             ; set for numeric operand and result, to C
       CP     #DF             ; 'CODE', 'VAL' and 'LEN' now give carry set
       JR     NC,NO_$         ; Skip with higher codes
       RES    6,C             ; Else, signal 'string operand'
NO_$   CP     #EE             ; 'STR$' and 'CHR$' now give carry reset
       JR     C,S_PUSHPO      ; Skip unless one of the above two
       RES    7,C             ; Else, signal 'string result'
S_PUSHPO
       PUSH   BC              ; Now stack the priority and operation code
       RST    #20             ; Advance the BASIC pointer
       JP     S_LP1           ; Loop back to consider the operand

; Evaluation continues at this point. A binary operator may follow, or we may
; have reached the end of the expression. In both cases, the stack must be 
; examined for any pending operations to be performed.
; Note that this entry point is vectored for use by the FN o() and FN o$()
; functions to allow re-entry of the evaluator from external ROM handlers.

CONT2  RST    #18             ; Get current character
       LD     B,#00           ; Pre-load B with 0 for 'end of expression'
       LD     C,A             ; Copy character code to C
       LD     HL,#2795        ; The table of binary operators in ROM
       CALL   #16DC           ; Call INDEXER to lookup
       JR     NC,S_LOOP       ; If not found, jump forward with B=0
       LD     C,(HL)          ; Get operation code in C ($C3-$CF)
       LD     HL,#26ED        ; Table of operator priorities (offset by $C3)
       ADD    HL,BC           ; Index into the table
       LD     B,(HL)          ; Get required priority

; The following loop performs the actual operations. The priority of the
; current operation is compared to that of any pending operation, and if it's
; higher then scanning continues to evaluate the next operand. Else, the
; pending operation is performed by calling the calculator after checking the
; operand(s) for the correct type.

S_LOOP POP    DE              ; Get pending operation and priority
       LD     A,D             ; Pending priority goes to D
       CP     B               ; Compare against current priority
       JR     C,S_TIGHTER     ; Jump if current priority is higher
       AND    A               ; A pending priority of zero signals
       JP     Z,#0018         ; 'no operations left', so exit via GET-CHAR
       PUSH   BC              ; Stack current priority and operation code
       LD     HL,#5C3B        ; FLAGS
       LD     A,E             ; Get pending operation code
       CP     #ED             ; This is the code for 'USR-numeric'
       JR     NZ,STK_LST      ; Skip if not 'USR'
       BIT    6,(HL)          ; 'USR' may have a numeric or string argument,
       JR     NZ,STK_LST      ; skip if numeric
       LD     E,#99           ; Else, change the operation in 'USR-string'

; Now check if the operand is of correct type. Bit 6 of FLAGS is set for a
; numeric value on the top of the calculator stack, reset for a string. This is
; now compared to bit 6 of the pending operation code.

STK_LST
       PUSH   DE              ; Save pending priority and code
       LD     A,(HL)          ; Test bit 6 of FLAGS against bit 6 of the pending
       XOR    E               ; operation code
       AND    #40
S_ERR  JP     NZ,#1C8A        ; If they don't match, report 'Nonsense in BASIC'
       LD     A,E             ; Get operation code again
       AND    #3F             ; Mask off the type bits 6 and 7; this yields an
       CP     #1D             ; operation code for the calculator.
       JR     Z,S_VAL         ; Exclude 'VAL', which is handled separately
       CP     #06             ; Jump unless operation is 'to-power'
       JR     NZ,S_CALC

; The following code tests for X ^ Y where X < 0. On the standard Spectrum,
; this throws an error 'Invalid argument' since it always calculates the
; result using X ^ Y = EXP(Y * LN(X)), and X cannot be negative for LN.
; We'll do it smarter: If X is negative AND Y is an integer, we'll calculate
; the result by taking EXP(Y * LN(ABS(X))) and negating it if Y is an odd
; number, so we still can calculate powers of negative numbers as long as the
; power is an integer.
; Note: The BASICODE book doesn't specify whether a negative value of X is
; allowed, but I've seen many programs breaking on the inability of ZX BASIC
; to handle this...

       RST    #28             ; invoke calculator for X ^ Y
       DEFB   #01,#31,#36     ; exchange, duplicate, less-0 (test X for <0)
       DEFB   #00,LESS0-$     ; jump-true, to LESS0

; Here X is >= 0, so just calculate the result using the 'to-power' operation.

       DEFB   #01,#06,#38     ; exchange, to-power, end-calc (performs X ^ Y).
       JR     S_TEST          ; Exit to S_TEST
LESS0  DEFB   #2A,#25,#01     ; abs, ln, exchange (Y now on TOS)
       DEFB   #31,#31,#27     ; duplicate, duplicate, int [LN(X), Y, Y, INT(Y)]
       DEFB   #03,#38         ; subtract (Y-INT(Y) on TOS)
       CALL   #34E9           ; Test Y-INT(Y); if Y is not an integer then
       JP     NC,#34E7        ; report 'Invalid argument'.
       RST    #28
       DEFB   #02,#31,#34     ; delete, duplicate [LN(X), Y, Y], stk-data
       DEFB   #40,#B0,#00     ; The next four bytes stack literal number 2
       DEFB   #02,#05,#31     ; division, duplicate [LN(X), Y/2, Y/2]
       DEFB   #27,#03,#38     ; int, subtract, end-calc [LN(X), Y/2-INT(Y/2)]
       CALL   #34E9           ; Now test Y/2-INT(Y/2) for zero
       PUSH   AF              ; Carry will be set if Y was an even number
       RST    #28
       DEFB   #02,#04,#26     ; delete, multiply, exp
       DEFB   #38             ; end-calc [EXP(Y*LN(ABS(X)))]
       POP    AF              ; Retrieve carry flag
       CALL   NC,#346E        ; If reset, Y was odd so negate the result
       JR     S_TEST          ; Jump forward

; This calls the VAL vector in BCFN.ASM which evaluates a number. In BASICODE,
; the argument of the VAL function should strictly be a numeric literal.
; Non-numeric arguments will give 'undefined' results. In ZX BASIC, the
; argument will be evaluated as an expression which is a very powerful feature
; by itself, but it's also prone to stop the program with 'Nonsense in BASIC'
; or another error when the expression is not a valid one in some respect.
; Rather than to throw this at an unsuspecting user, I decided to follow the
; BASICODE spec here.

S_VAL  CALL   VAL             ; Call the vector
       JR     S_TEST          ; Jump to examine the result

; All other functions are handled here. The operation code is passed to the B
; register and the calculator called with function $3B which signifies that the
; B register specifies the operation to be performed.

S_CALC LD     B,A             ; Pass operation code to B
       RST    #28             ; Invoke calculator
       DEFB   #3B,#38         ; fp-calc-2, end-calc

; Now set bit 6 of FLAGS according to the result type 

S_TEST POP    DE              ; Retrieve pending priority and operation code
       LD     HL,#5C3B        ; Point to FLAGS
       SET    6,(HL)          ; Assume numeric result
       BIT    7,E             ; Bit 7 is set for numeric result
       JR     NZ,LOOPEND      ; Skip if indeed numeric
       RES    6,(HL)          ; Else, signal 'string result'
LOOPEND
       POP    BC              ; Retrieve current priority and operation code
       JR     S_LOOP          ; .. and loop back for next pending operation

; The current operator has a higher priority than the pending operation so has
; to be evaluated first.

S_TIGHTER
       PUSH   DE              ; Stack pending operation and priority again
       LD     A,C             ; Get current operator code
       BIT    6,(IY+1)        ; Is the value on the calculator stack numeric?
       JR     NZ,S_NEXT       ; Yes, jump
       AND    #3F             ; Mask off the type bits
       ADD    A,#08           ; Operators =, <>, <, >, <=, >=, AND, and + have
       LD     C,A             ; string equivalents 8 higher; transfer to C
       CP     #10             ; Is the operator 'AND'?
       JR     NZ,NOT_AND      ; skip if not
       SET    6,C             ; The right-hand operand for AND must be numeric
       JR     S_NEXT          ; Jump forward
NOT_AN JR     C,S_ERR         ; -, *, /, ^, and OR cannot have string operands
       CP     #17             ; Test against $17 for 'string addition'
       JR     Z,S_NEXT        ; Result of string addition is also a string
       SET    7,C             ; All other string operators have numeric result
S_NEXT PUSH   BC              ; Now stack the priority and operation code
       RST    #20             ; Advance BASIC pointer
       JP     S_LP1           ; .. and loop back for second operand

; --------------------------
; Evaluation of FN functions
; --------------------------
; User-defined functions (using DEF FN) are evaluated here. As explained by
; DEF FN, the representation in memory differs significantly from the original
; Spectrum BASIC. FNs are stored as variables, containing a 'local' variable
; area to store the arguments values. The LOOKVARS routine scans this area
; (pointed to by DEFADD) first before looking in the global variables area.
; After this area, there is a pointer to the expression after '=' in the DEF FN
; statement (relative to PROG) which is then evaluated by recursively calling
; SCANNING (note that you cannot call the same FN recursively since there is
; no way to stop it from calling itself!).
; DEF FN was legalised in the second edition of BASICODE-3 (1988), but only for
; numeric FNs with only one parameter. However it has always been present in
; BEXT to handle LEFT$, MID$, RIGHT$ and EOF.

SF_SUB RST    #20             ; Next character
       LD     C,#80           ; Signal 'look for FN type variable'
       CALL   LOOKV1          ; Look up the function in the VARS area
       JP     C,#2812         ; If not found, report 'FN without DEF'
       PUSH   BC              ; Save type of function in C
       EX     DE,HL           ; Save HL while advancing past the initial '('
       RST    #20
       EX     DE,HL
       INC    HL              ; Step past the null and length bytes
       INC    HL
       INC    HL
       PUSH   HL              ; Save the pointer
       LD     A,(HL)          ; Get first character of parameter area
       CP     #80             ; A $80 byte signals 'no parameters'
       JR     Z,SF_BR2        ; .. so skip the next loop

; For each argument, SCANNING is called recursively to evaluate it and store
; its value in the FN's local 'variables' area.

SF_ARG PUSH   HL              ; Save HL while the argument is evaluated
       CALL   SCANNING
       POP    HL
       LD     A,(#5C3B)       ; Get FLAGS byte (bit 6 signals type of argument)
       XOR    (HL)            ; Match this against the type of the parameter
       AND    #40
       JR     NZ,SF_MIS       ; Report 'Parameter error' if they don't match
       LD     B,#01
       CPIR                   ; Skip past the null byte after the param's name
       EX     DE,HL           ; This goes to DE as destination
       LD     HL,(#5C65)      ; Fetch STKEND
       LD     BC,#0005        ; 5 bytes to move
       SBC    HL,BC           ; Point to start of value to be copied
       LD     (#5C65),HL      ; Reset STKEND
       BIT    6,(IY+1)        ; Is the value numeric?
       JR     NZ,SF_CPY       ; Yes, skip
       LD     (HL),A          ; Else, ensure that the 'relative' flag is reset
SF_CPY LDIR                   ; Copy over the 5 bytes
       EX     DE,HL           ; Swap source and destination
       LD     A,(HL)          ; Get first byte of next parameter
       CP     #80             ; An $80 byte signals 'no further parameters'
       JR     Z,SF_BR2        
       EX     DE,HL           ; Save HL
       RST    #18
       CP     #2C             ; Is current character a ','?
       JR     NZ,SF_DEF       ; Exit from the loop if not
       RST    #20             ; Else, advance pointer and loop back for
       EX     DE,HL           ; the next argument
       JR     SF_ARG

; We now have to deal with case that there are fewer arguments specified than
; the function has parameters. Normally this would have been an error, but the
; case of MID$(A$,N) is a legal exception to this (it was legalised in the
; second edition of BASICODE-3). In order to signal this to the function's
; handler, the 5 bytes of the excess parameters are set to $FF 00 00 00 00.
; The MID$ handler in BCFN.ASM picks this up and acts accordingly.
; Of course, this 'feature' leads to interesting results when abused (e.g.
; DEF FN f(x,y)=x+y will return a very large number when called with just one
; argument) but chances of this happening in a BASICODE program are negligible
; since only one parameter is allowed, and you cannot call a function without
; arguments!

SF_DEF EX     DE,HL           ; Pointer to function in VARS area to HL
SFD_LP XOR    A
       LD     B,1
       CPIR                   ; Find the terminating null byte for this arg
       DEC    A               ; A is now $FF, enter this into the first byte
       LD     (HL),A
       INC    A               ; Set A to zero again
       INC    HL              ; Point to second byte of argument
       LD     B,4             ; Set the remaining 4 bytes to zero
SFDFIL LD     (HL),A
       INC    HL
       DJNZ   SFDFIL
       LD     A,(HL)          ; Get first byte of next parameter's name
       CP     #80             ; Loop back for all remaining parameters
       JR     NZ,SFD_LP       ; until the $80 end marker has been reached

; At this point, all parameters have been evaluated or set to default.

SF_BR2 EX     DE,HL           ; Save HL
       RST    #18
       CP     #29             ; Current character must be ')'
SF_MIS JP     NZ,#288B        ; else report 'Nonsense in BASIC'
       EX     DE,HL           ; Swap HL back
       INC    HL
       LD     C,(HL)          ; Get pointer to DEF FN's expression in BC
       INC    HL
       LD     B,(HL)
       LD     HL,(#5C53)      ; It is relative to PROG
       ADD    HL,BC
       LD     (#5C5D),HL      ; Set CH-ADD (DE holds current address)
       LD     HL,(#5C0B)      ; Get current pointer to arguments in DEFADD
       EX     (SP),HL         ; Exchange with pointer to current FN's arguments
       LD     (#5C0B),HL      ; saved earlier; this will be the new DEFADD
                              ; (thus you can safely call another FN from an FN
                              ; as long as they aren't called recursively!)
       PUSH   DE              ; Save pointer after FN function call
       CALL   SCANNING        ; Now call SCANNING recursively to evaluate the
       POP    HL              ; FN's expression
       LD     (#5C5D),HL      ; Restore CH-ADD
       POP    HL              ; Retrieve previous DEFADD address
       LD     (#5C0B),HL
       POP    BC              ; Retrieve type of FN (numeric/string) in C
       LD     A,(#5C3B)
       XOR    C               ; Match bit 6 of flags with bit 6 of C
       AND    #40
       JR     NZ,LV_RPC       ; 'Nonsense in BASIC' if they don't match
       RST    #20             ; Advance to next character in program
       JP     CONT2           ; Continue evaluation

;------------------------------------------------------------------------------
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

; Returns:
; - when 'variable not found':
;   Carry flag set
;   Zero flag set when search was for an array or FN function
;   HL points to the first character of the requested name.
;
; - when 'variable found':
;   Carry flag reset
;   Zero flag set when the search was for an array or FN function
;   HL points to the location after the variable's name (the null byte).
;   DE points to the first character of the requested name.
;------------------------------------------------------------------------------

LOOKVARS
       LD     C,#00           ; Normal entry point - clear the C register

; The entry point below is used by DEFFN and FN with C holding $80

LOOKV1 RST    #18             ; get first character
       CALL   #2C8D           ; it must be alphabetic
       JR     NC,LV_RPC       ; else report 'Nonsense in BASIC'.
       PUSH   HL              ; save address of first character
       AND    #1F             ; first letter range is now $01-$1A
       OR     C               ; mask in any 'type' bits in C
       LD     C,A
       LD     B,#01           ; initialise name counter to 1.
V_CHAR RST    #20             ; loop for next character
       CALL   #2C88           ; which has to be alphanumeric
       JR     NC,V_TEST       ; if not, skip out of the loop
       INC    B               ; increment character count
       JR     NZ,V_CHAR       ; but do not allow > 255 characters!
LV_RPC RST    8
       DEFB   #0B             ; Report C - 'Nonsense in BASIC'
V_TEST CP     #24             ; check for '$'
       JR     NZ,V_ARRAY      ; skip if not string
       RES    6,(IY+1)        ; else, signal 'string variable, array or FN'.
       RST    #20             ; get next character
       CP     #28             ; is it '(' ?
       JR     Z,V_SEARCH      ; yes, go searching for string arrays and FNs
       SET    5,C             ; signal 'simple string variable'
       JR     V_FN            ; jump forward
V_ARRAY                       
       SET    6,(IY+1)        ; signal 'numeric variable, array or FN'
       SET    6,C             ; look only for this numeric types
       CP     #28             ; now test for '('
       JR     Z,V_SEARCH      ; it's a numeric array or FN, go searching
       SET    5,C             ; signal 'simple numeric variable'

; At this point, we are searching for simple numeric or string variables.
; However, when evaluating a user DEFined FN function, we must first look for
; any matching arguments before searching the variables area. In this case,
; DEFADD will point to the FN's parameter area which is laid out in memory as
; a 'local' variables area (terminated by a $80 byte). When not evaluating an
; FN function, DEFADD-hi will be zero.

V_FN   LD     A,(#5C0C)       ; Get DEFADD-hi
       AND    A
       JR     Z,V_SEARCH      ; If zero, just go searching VARS area
       LD     HL,V_RETAD      ; V_RETAD is used as return point after searching
       EX     (SP),HL         ; the FN's arguments, put this on the stack
       PUSH   HL              ; Save the pointer to the first character as well
       LD     HL,(#5C0B)      ; Get the pointer to the FN's parameter area
       JR     V_EACH          ; Now go searching the FN's arguments first

; After searching the parameter area, come here

V_RETAD
       RET    NC              ; Return if a match found in the FN's arguments
       PUSH   HL              ; Save pointer to first character again

; Now search the variables area

V_SEARCH
       LD     HL,(#5C4B)      ; VARS
V_EACH LD     A,(HL)          ; Get first character of variable
       CP     #80             ; A byte value of $80 marks the end of the area
       JR     Z,V_80          ; (either VARS or FN's arguments)
       CP     C               ; Match with first character of requested name
       JR     NZ,V_NEXT       ; and type; skip if no match
       POP    DE              ; Retrieve pointer to requested name in DE
       PUSH   DE
       PUSH   BC              ; Save name counter & type
       PUSH   HL              ; Save pointer to first character in VARS
       DEC    B               ; One less character to match now
       JR     Z,V_CHECK       ; skip past the loop for final check
V_MATCH
       INC    HL              ; Increment pointer in VARS
V_SP   INC    DE
       LD     A,(DE)          ; Get next character from requested name
       CP     #21
       JR     C,V_SP          ; Skip over any spaces and control codes
       OR     #20             ; Convert any upper case to lower case
       CP     (HL)            ; Now match with next character from variable
       JR     NZ,V_PTR        ; skip if no match
       DJNZ   V_MATCH         ; loop for all characters

; A final check is to be made to see if the end of the name has been reached -
; this is marked by a zero byte.

V_CHECK
       INC    HL              ; Next character
       LD     A,(HL)
       AND    A               ; Test for zero
       JR     Z,V_FOUND       ; We have a full match!
V_PTR  POP    HL              ; else, restore pointer to first character
       POP    BC              ; and restore name counter in B
V_NEXT CALL   NEXT_ONE        ; Skip to next variable
       JR     V_EACH          ; Loop back

; We've come to the end of the VARS or FN's arguments area

V_80   POP    HL              ; Retrieve pointer to requested name
       SCF                    ; Signal 'variable not found'
       BIT    5,C             ; Set zero flag for arrays and FN functions
       RET                    ; Finished

; A matching variable or FN argument has been found (carry flag reset here)
; HL points to the location after the variables name (the null byte).

V_FOUND
       POP    BC              ; Discard pointer to first character
       POP    BC              ; Retrieve BC
       POP    DE              ; DE points to requested name
       BIT    5,C             ; Set zero flag for arrays and FN functions
       RET                    ; Finished

; The NEXT-ONE routine finds the next variable in the VARS area.
; This routine is much shorter than its ROM counterpart, since it only has to
; cater for variables and not line numbers!
; It simply tests bit 5 of the first byte - if set, it's a simple numeric or 
; string variable and the length after the name + null byte will be 5.
; In case of arrays and FN functions, the next 2 bytes will contain the length
; of the variable's body.

NEXT_ONE
       BIT    5,(HL)          ; A simple variable will have bit 5 set
       PUSH   AF              ; Save the flag
N_O_1  LD     A,(HL)          ; Now enter a loop to skip past the name
       INC    HL
       AND    A               ; it's terminated by a null byte
       JR     NZ,N_O_1
       LD     DE,#0005        ; Assume simple variable - 5 bytes
       POP    AF              ; Retrieve flag
       JR     NZ,N_O_2        ; Jump if indeed a simple variable
       LD     E,(HL)          ; Else, get length from next 2 bytes
       INC    HL
       LD     D,(HL)
       INC    HL
N_O_2  ADD    HL,DE           ; Skip past the variable's body
       RET

; -----------------------------------------------
; Find address of destination element in an array
;------------------------------------------------
; This routine is called from the Class 01 command handler and SCANNING, to
; locate the address of an array element. It returns HL pointing to the
; location before the requested element.
; Array dimensions have the usual layout; one byte for the number of dimensions
; followed by 2 bytes indicating the size of each dimension.
; Note: Since subscripts start at 0, dimensions are one higher than specified
; in a DIM statement! Also string arrays have only 5 bytes for each element
; specifying a flag for absolute or relative address, followed by 2 bytes for
; the address, and finally 2 bytes for the length. The strings themselves are
; stored in the string space (absolute address) or in the program area itself
; (then the address is relative to PROG base, since the BASIC program may be
; moved in memory when opening or closing an I/O channel!).

DESTAD
       INC    HL              ; Step past null byte and length bytes
       INC    HL
       INC    HL
       LD     B,(HL)          ; Get number of dimensions
       EX     DE,HL           ; Save pointer in DE
       LD     HL,#0000        ; Initialise HL to zero
       PUSH   HL              ; Push this on the machine stack
       JR     D_COUNT         ; Jump forward to consider first subscript
D_COMMA
       PUSH   HL              ; This loop is taken for every subsequent
       RST    #18             ; subscripts; a comma must follow
       CP     #2C
       JP     NZ,#2A20        ; Else report 'Subscript wrong'
D_COUNT
       RST    #20             ; Advance to next subscript
       POP    HL              ; Retrieve overall index
       PUSH   BC              ; Save dimension counter and array type
       PUSH   HL              ; Save index again
       CALL   #2AEE           ; This calls the 'LD DE,(DE+1)' routine - it
                              ; fetches the next dimension size in DE and
                              ; leaves HL pointing to the last byte of it
       EX     (SP),HL         ; Save HL and retrieve overall index
       EX     DE,HL           ; Current dimension now in HL, index to DE

; Now call INT_EXP to evaluate the next subscript and check if it is in range
; 0 to 'dimension size' minus 1. Note that 'dimension size' is 1 higher than
; specified in the DIM statement (conform BASICODE standard) so we have to 
; compensate for this before checking the range!

       DEC    HL              ; Decrement size
       CALL   INT_EXP         ; Evaluate next subscript and check range
       INC    HL              ; Balance the DEC above
       CALL   MULT            ; Multiply size by running overall index in DE
       ADD    HL,BC           ; Add the current index in BC to the result
       POP    DE              ; Retrieve pointer to dimension size
       POP    BC              ; Retrieve dimension counter and array type
       DJNZ   D_COMMA         ; Loop for all dimensions
       PUSH   HL              ; Save overall index
       RST    #18
       CP     #29             ; A closing bracket ')' must follow
       JP     NZ,#2A20        ; Else, report 'Subscript wrong'
       RST    #20             ; Advance BASIC pointer
       POP    HL              ; Retrieve overall index
       BIT    6,C             ; Test numeric/string array flag
       LD     B,H             ; Transfer overall index to BC
       LD     C,L
       ADD    HL,HL           ; Multiply by 5 - the size of each array element
       ADD    HL,HL
       ADD    HL,BC
       ADD    HL,DE           ; HL now points to one location before the
                              ; requested element
       RET    NZ              ; Return now with numeric arrays
       RES    6,(IY+1)        ; Else, reset flag to string (it was set to
       RET                    ; numeric when evaluating the subscripts)

; The following subroutine evaluates each subscript and returns it in BC. It is
; also checked against the current dimension size in HL.

INT_EXP
       PUSH   DE              ; Save registers
       PUSH   HL
       CALL   EX_1NUM         ; Evaluate the next subscript
       CALL   #1E99           ; Fetch it into BC
       POP    HL              ; Restore registers
       POP    DE
       SBC    HL,BC           ; Check the subscript against the size in HL
       ADD    HL,BC           ; Restore HL
       RET    NC              ; Return if subscript is in range
       RST    8               ; Else, report 'Subscript wrong'. Note: Two JP's
       DEFB   #02             ; to $2A20 above could be replaced by JR's here!

; This subroutine is called from just one occasion in the DIM handler. It calls
; the MULT subroutine below, giving 'Out of memory' if the result overflows.

GET_HL CALL   MULT            ; Multiply HL by DE
       JP     C,#1F15         ; Report 'Out of memory' if over 65535
       RET                    ; Done

; ---------------------------------------
; A faster 16-bit multiplication routine!
; ---------------------------------------
; This routine is used for multiplying HL by DE instead of the ROM routine at
; $30A9. It has been shamelessly taken from an example in the Hisoft Devpac
; manual :-o. Still, I've managed to save one instruction by replacing
; 'OR D; SCF' by 'CP D' at MU1 :-).
; The routine is generally much faster since it only counts the bits in the
; multiplier which are significant. The smaller of the two 16-bit values is
; taken as multiplier, and since the result must also fit in 16 bits, this
; value cannot be greater than 255 so we only have to consider at most 8 bits
; rather than 16!

MULT   XOR    A               ; Clear A and carry flag
       SBC    HL,DE           ; Test whether HL is greater than DE
       ADD    HL,DE
       JR     NC,MU1          ; If yes, skip
       EX     DE,HL           ; Else, swap numbers so the lesser goes to DE
MU1    CP     D               ; If DE > 255, the result will certainly overflow
       RET    C               ; since HL > DE, so return carry set if D > 0
       OR     E               ; This will copy E to A and set zero flag if E=0
       LD     E,D             ; This will set DE to zero since D is also zero
       JR     NZ,MU4          ; If E was nonzero, jump to do the multiplication
       EX     DE,HL           ; Else, result will be zero so return with HL = 0
       RET
MU2    EX     DE,HL           ; A '1' bit has been shifted out from the
       ADD    HL,DE           ; multiplier so add the multiplicant in HL to DE
       EX     DE,HL
MU3    ADD    HL,HL           ; For each iteration, shift the multiplicant left
       RET    C               ; Return carry set if overflow
MU4    RRA                    ; Shift out next bit of the multiplier
       JR     NC,MU3          ; If this bit was 0, just shift the multiplicant
       AND    A               ; Test if all '1' bits have been shifted out
       JR     NZ,MU2          ; If not, loop back
       ADD    HL,DE           ; A final addition will put the result in HL,
       RET                    ; setting the carry flag if it overflows

; -----------------------
; The LET command handler
; -----------------------
; This routine is called whenever a value is to be assigned to a variable or
; array element. It is called indirectly by LET from the Class 02 handler, and
; directly by FOR, READ, and INPUT.
; On entry, the value to be assigned is on the calculator stack. In case of an
; existing variable or array element, DEST points to the location before the 5
; bytes which hold its value. In case of a new variable, the low byte of STRLEN
; holds the first byte of the name (with type bits masked in) and the high byte
; holds the number of characters in the name.
; In case of a numeric assignment, the 5 bytes from the calculator stack are 
; simply copied to the destination in the VARS area. However in case of a
; string, these 5 bytes will only hold a pointer to the start of the string in
; memory and it's length. The actual string may be a literal string in the PROG
; area, which is liable to move when a channel is opened, or reside in the
; E_LINE or WORKSP area which is only a temporary storage. In the first case,
; the pointer is stored as a relative pointer to PROG. In the latter case, the
; string has to be copied to the string space area between the GOSUB stack and
; RAMTOP (see CLEAR command). This may involve some cleaning up (Garbage
; collecting), and when this doesn't help an error 'S Out of string space' is
; thrown (which may be somewhat embarrassing to unsuspecting users!). See the
; CLEAR command on how to set the size of the string space.

LET    BIT    6,(IY+1)        ; Test the numeric/string flag
       JR     NZ,L_NUM        ; Jump if this is a numeric assignment
       CALL   L_PAR           ; Locate and if necessary store the string in the
       CALL   #2AB2           ; string space and re-stack its parameters
L_NUM  LD     HL,(23629)      ; Get pointer in DEST
       BIT    1,(IY+55)       ; Is it an existing variable?
       JR     Z,L_EXIST       ; Yes, jump
       LD     L,(IY+57)       ; L holds length of new variable's name
       LD     H,#00
       LD     BC,#0006        ; Six more bytes are required; one for the end
       ADD    HL,BC           ; marker after the name and 5 for the value
       LD     B,H
       LD     C,L
       LD     HL,(23641)      ; E_LINE
       DEC    HL              ; Point to last location of VARS area
       CALL   #1655           ; Make room for new variable
       INC    HL
       EX     DE,HL           ; The destination pointer goes to DE
       LD     HL,(23629)      ; DEST points to the name in the BASIC program
       LD     BC,(23666)      ; Get length of name in B and first byte of name
       LD     A,C             ; in C; transfer this to A
L_CHAR LD     (DE),A          ; The following loop copies the characters of the
       INC    DE              ; name from the BASIC area to the VARS area
L_SPC  INC    HL
       LD     A,(HL)
       CP     #21             ; .. but skip any spaces and control codes
       JR     C,L_SPC
       OR     #20             ; All characters but the first are converted to
       DJNZ   L_CHAR          ; lower case
       XOR    A               ; A zero byte marks the end of the name
       LD     (DE),A
       EX     DE,HL           ; Swap pointers to synchronise with code below
L_EXIS INC    HL              ; Step past the null byte after the name
       EX     DE,HL           ; Destination pointer goes to DE
       LD     HL,(23653)      ; STKEND
       LD     BC,#0005        ; 5 bytes to be copied
       AND    A
       SBC    HL,BC
       LD     (23653),HL      ; Reset STKEND
       PUSH   DE
       LDIR                   ; Copy the 5 bytes
       POP    HL              ; Return HL pointing to the destination
       RET

; The following subroutine handles the actual storage of strings. The string is
; copied to the string space if necessary. In case of a literal string in a
; BASIC program, the string is not copied but a pointer returned relative to
; the base of the program. The registers are returned as follows:
; A : zero for an absolute pointer, 1 for a relative pointer
; BC: Length of string
; DE: Address of start of string (either absolute or relative to PROG).

L_PAR  CALL   #2BF1           ; Call STK-FETCH to get parameters in BC and DE
       LD     A,B             ; Test for null length
       OR     C
       JR     NZ,NO_NULL      ; Jump if not null string
       LD     D,B             ; Else, set DE to zero too and return.
       LD     E,C
       RET
NO_NUL XOR    A               ; Clear relative flag
       SBC    HL,DE           ; Test address of string against STKEND (in HL)
       RET    C               ; Return if higher (it's already in string space)
       LD     HL,(23641)      ; Get E_LINE
       SCF
       SBC    HL,DE           ; Carry will be set if string is in E_LINE or
       JR     NC,L_PROG       ; WORKSP area; jump if it's below

; The string is either in E_LINE or WORKSP (as result of a direct command,
; INPUT command or calculator operation). Since these areas are temporary
; storage, the string must be moved to permanent storage in the string space
; area. The area is checked for free space, and if insufficient the GARBAGE
; routine is called to clean up unused sections. The check is then repeated and
; if there's still insufficient space the error 'S Out of string space' is
; reported.

       LD     HL,(STRPTR)     ; Get pointer to first used location
       AND    A               ; (initially equal to RAMTOP)
       SBC    HL,BC           ; It runs downwards with each string added
       INC    HL              ; Add 1 for check against STRS pointer
       PUSH   DE              ; Save source address of string
       EX     DE,HL           ; Destination address goes to DE
       LD     HL,(STRS)       ; Pointer to bottom of string space
       SBC    HL,DE           ; Check the new pointer against STRS
       JR     C,L_OK          ; Jump if space is sufficient
       PUSH   BC
       CALL   GARBAGE         ; Else, save BC while doing clean-up
       POP    BC
       LD     HL,(STRPTR)     ; Now repeat the check with new STRPTR
       AND    A
       SBC    HL,BC
       INC    HL
       EX     DE,HL
       LD     HL,(STRS)
       SBC    HL,DE
       JR     C,L_OK          ; Jump if there is enough room now
       CALL   ERROR           ; Else, report 'S Out of string space'
       DEFB   #1B
L_OK   POP    HL              ; Retrieve source address of string
       DEC    DE              ; Set STRPTR to one below the first byte of the
       LD     (STRPTR),DE     ; new string to be added
       INC    DE
       PUSH   DE              ; Save BC and DE
       PUSH   BC
       LDIR                   ; Copy over the string
       POP    BC              ; Retrieve BC and DE
       POP    DE
       XOR    A               ; Signal 'string has absolute address' and return
       RET

; Strings in the program area don't need to be copied to the string space. They
; are referenced using a pointer relative to PROG, so the STKSTR routine in
; SCANNING can correctly convert this to an absolute address before putting it
; onto the calculator stack, even if the PROG area has been moved due to I/O
; channels which have been opened. The first of the 5 bytes is set to 1 to 
; signal that the address is relative.

L_PROG LD     HL,(23635)      ; Get PROG
       EX     DE,HL           ; Swap address and PROG base
       LD     A,#01           ; Signal 'address is relative'
       SBC    HL,DE           ; Subtract base address (carry reset from above)
       EX     DE,HL           ; Return this in DE
       RET    NC              ; .. but do a final check if it's really in PROG
       ADD    HL,DE           ; Else, cancel the subtraction
       EX     DE,HL           ; Note: it's very unlikely that we'll ever come
       XOR    A               ; here - but probably an extra safeguard?
       RET                    ; Return with A signalling absolute address again

; ------------------
; GARBAGE COLLECTING
; ------------------
; As explained in CLEAR and LET above, strings which do not reside in the BASIC
; program itself are stored in the 'string space' between the FOR/GOSUB stack
; and RAMTOP. This area fills up downwards as new strings are added, up to the
; point where the pointer to the free space (STRPTR) hits the bottom at (STRS).
; When an existing string variable is re-assigned a new string, only its
; pointer is adjusted. The string itself is NOT removed. Note that a string may
; be pointed to by more variables, e.g. after LET A$=B$ or even when assigning
; substrings.
; Eventually, when the string space has been filled up completely, we need to
; clean it up and remove the slack space ('Garbage') which has been accrued by
; this process. This involves scanning the variables area for all strings and
; reclaiming all unused space. Of course this can be a time-consuming process
; and depending on the amount of string space reserved and how much string
; manipulation is done it can occur more or less often.
; E.g. 'LET A$="":FOR I=1 to 255:LET A$=A$+CHR$(I):NEXT I' needs at least 509
; bytes of string space and will trigger a Garbage Collect after just 32
; iterations. However, then doing LET B$=A$ will only cost 7 bytes of variable
; space as opposed to 258 on ZX BASIC!

; This subroutine scans the variables area for the next string variable or
; array element which resides in the string space area. It is normally entered
; at G_NEXT and returns carry reset when the end of the variables area has been
; reached.

G_NXT1 INC    HL              ; This is part of the loop - skip past remaining
       INC    HL              ; bytes
       INC    HL
G_NEXT DEC    BC              ; BC holds remaining array elements or 1 on the
       LD     A,B             ; initial call and counts down
       OR     C
       JR     NZ,G_ELEM       ; Jump if more array elements to consider
G_VAR  LD     A,(HL)          ; Consider next variable
       CP     #80             ; End marker reached?
       RET    Z               ; If yes, return with carry flag reset
       RRCA
       OR     (HL)            ; If either bit 6 or 7 are set, it's a numeric
       AND    #40             ; variable or FN which we don't have to consider
       JR     Z,G_STR
       CALL   NEXT_ONE        ; Skip to next variable
       JR     G_VAR
G_STR  LD     E,(HL)          ; Get first byte of name holding the type bit
       LD     B,#01
       CPIR                   ; Find the null byte at the end of the name (A=0)
       BIT    5,E             ; Test the array bit; it's 0 for a string array
       LD     DE,#0001        ; Initialise DE to 1 for 'simple string'
       JR     NZ,G_COUNT      ; Jump with simple string variables
       INC    HL              ; Step past the length bytes of the array
       INC    HL
       LD     B,(HL)          ; Get number of dimensions
       INC    HL
G_MULT LD     A,(HL)          ; Get next dimension size (low byte)
       INC    HL
       PUSH   HL              ; Save the pointer
       LD     H,(HL)
       LD     L,A             ; HL now holds dimension size
       CALL   MULT            ; Multiply HL by DE
       EX     DE,HL           ; Running value to DE
       POP    HL              ; Retrieve pointer
       INC    HL
       DJNZ   G_MULT          ; Loop back for all dimensions
G_COUN LD     B,D             ; Total number of array elements goes to BC
       LD     C,E             ; (or 1 in case of a simple string)
G_ELEM LD     A,(HL)          ; Get first byte (the absolute/relative flag)
       INC    HL
       LD     E,(HL)          ; Low byte of address
       INC    HL
       LD     D,(HL)          ; High byte of address
       AND    A               ; Test the flag (nonzero means relative; we don't
       JR     NZ,G_NXT1       ; have to consider these so loop back)
       PUSH   HL              ; Save pointer
       LD     HL,(STRPTR)     ; Any string above STRPTR has already been
       SBC    HL,DE           ; considered but if it's below STRPTR there may
       JR     NC,G_STRS       ; be 'garbage' above it
       POP    HL              ; Else, retrieve pointer and loop back
       JR     G_NXT1
G_STRS LD     HL,(STRS)       ; Check the string's address if it's really in
       SBC    HL,DE           ; the string space
       POP    HL              ; Retrieve pointer
       JR     NC,G_NXT1       ; If not in string space, loop back
       RET                    ; Else, return carry set (we've found one)

; The main garbage collecting routine

GARBAG XOR    A               ; Signal 'no strings have been moved yet'
       EX     AF,AF'          ; this flag goes to AF'
       LD     HL,(23730)      ; Reset STRPTR from RAMTOP - we'll adjust it
       LD     (STRPTR),HL     ; downwards as we scan the variables area

; The following loop scans the variables area for the longest string with the
; highest address in the string space area. Any slack space between this string
; and the running pointer STRPTR is reclaimed and then STRPTR is reset to the
; base address of this string. When all strings have been considered and all
; slack space ('garbage') has been reclaimed, an exit is made.

G_LOOP LD     HL,#0000        ; H_AD holds the highest address in use by
       LD     (H_AD),HL       ; a string - initialise this to zero
       LD     HL,(23627)      ; get VARS pointer
       LD     BC,#0001        ; Initialise BC to 1
G_FETC CALL   G_NEXT          ; Get next string variable or array element
       JR     NC,G_PTRS       ; Jump forward when no variables left to consider
       EX     AF,AF'
       LD     A,#01           ; Set flag to 1 to signal we're not done yet
       EX     AF,AF'
       PUSH   BC              ; Save BC
       INC    HL              ; HL points to third of five bytes and DE holds
       LD     C,(HL)          ; the address - now fetch length in BC
       INC    HL
       LD     B,(HL)
       INC    HL              ; Skip to next variable or array element
       PUSH   HL              ; Save this pointer
       EX     DE,HL           ; Now HL holds string base address
       ADD    HL,BC           ; Add length so HL now points past last byte
       EX     DE,HL           ; this goes to DE
       LD     HL,(H_AD)       ; Get running highest address
       SBC    HL,DE           ; Compare against this string's end address
       JR     Z,G_LEN         ; If equal, consider length of strings
       JR     NC,G_RSTOR      ; Jump if this string doesn't reach that far
       LD     HL,#0000        ; Else, initialise H_LEN, which counts the
       LD     (H_LEN),HL      ; longest string
       EX     DE,HL           ; Now update H_AD with this string's end address
       LD     (H_AD),HL       ; (in fact one-past the last byte)
G_LEN  LD     HL,(H_LEN)      ; Compare H_LEN with current length
       AND    A
       SBC    HL,BC
       JR     NC,G_RSTOR
       LD     (H_LEN),BC      ; Set H_LEN if current string is longer
G_RSTO POP    HL              ; Restore VARS pointer
       POP    BC              ; Restore BC
       JR     G_FETCH         ; Loop back for next string

; We now have found the longest string with the highest address in the string
; space. This string needs to be moved 'up' to reclaim any slack space
; (remember the area expands downwards!) and pointers in the VARS area need to
; be adjusted accordingly.

G_PTRS EX     AF,AF'
       DEC    A               ; Test the flag - if it was zero, all strings
       RET    NZ              ; have been considered so return.
       EX     AF,AF'          ; Save flag again for the next turn
       LD     HL,(H_AD)       ; Highest address in use below STRPTR + 1
       LD     DE,(STRPTR)     ; First free address
       LD     BC,(H_LEN)      ; Length of longest reference
       DEC    HL              ; Step down to last byte of string
       LD     A,B             ; Sanity check for zero length
       OR     C
       JR     Z,G_ENTER
       LDDR                   ; Move the string up
G_ENTE PUSH   DE              ; Save source and destination
       PUSH   HL
       EX     DE,HL           ; Find amount of bytes by which it has been
       SBC    HL,DE           ; moved up
       LD     (H_LEN),HL      ; Save this in H_LEN
       LD     HL,(23627)      ; Get VARS pointer
       LD     BC,#0001        ; Initialise BC
GP_NXT CALL   G_NEXT          ; Loop again for all string variables
       JR     NC,G_END        ; Jump when at end of variables
       EX     (SP),HL         ; Save HL; string's address is in DE
       AND    A
       SBC    HL,DE           ; Compare against original address in HL
       ADD    HL,DE
       EX     (SP),HL         ; Swap back
       JR     NC,NO_ADJ       ; Jump if this variable was below the moved one
       PUSH   HL              ; Save pointer
       LD     HL,(H_LEN)      ; Get distance
       ADD    HL,DE           ; Add this to the string's address
       EX     DE,HL           ; Swap this to DE
       POP    HL              ; Retrieve VARS pointer
       LD     (HL),D          ; Enter the new address
       DEC    HL
       LD     (HL),E
       INC    HL
NO_ADJ INC    HL              ; Step to next variable or array element
       INC    HL
       INC    HL
       JR     GP_NXT          ; Loop back
G_END  POP    HL              ; End of loop - drop original address
       POP    HL              ; Retrieve destination
       LD     (STRPTR),HL     ; Set STRPTR accordingly - one below new address
       JP     G_LOOP          ; Loop back for next scan

; -----------------------
; The FREE MEMORY routine
; -----------------------
; This routine works similar to the famous '65535-USR 7962' routine but does
; a bit more - Garbage collect is called first and then the amount of free
; memory is adjusted for free string space and reduced to allow the creation
; of one BASICODE tape channel. The routine is used by GOSUB 270 and vectored
; through the jump table at the start.

FREEME CALL   GARBAGE         ; Do garbage collecting
       CALL   #1F1A           ; This is 'USR 7962'
       LD     HL,(STRPTR)     ; Find the amount of free space in the string
       LD     DE,(STRS)       ; area in HL
       AND    A
       SBC    HL,DE
       SBC    HL,BC           ; Now perform '65535-USR 7962' but add free
       EX     DE,HL           ; string space - move this to DE
       LD     HL,(23635)      ; Find the amount of space occupied by the CHANS
       LD     BC,(23631)      ; area in HL
       SBC    HL,BC
       LD     BC,1043         ; Subtract the size of a BASICODE tape channel
       SBC    HL,BC
       EX     DE,HL           ; Amount of free memory to HL again
       JR     NC,FRE_1        ; Return this if a tape channel has been opened
       SBC    HL,BC           ; Else, subtract 1043 so opening a tape channel
       JR     NC,FRE_1        ; will not change the amount of free memory
       LD     HL,0            ; returned - but return 0 when 'out of memory'!
FRE_1  LD     B,H             ; Transfer the result to BC so the USR function
       LD     C,L             ; call will return it
       RET

H_AD   DEFW   0               ; Storage for garbage collection routines
H_LEN  DEFW   0

; -----------------------
; The DIM command handler
; -----------------------
; Apart from the fact that array names can have more than one letter, the DIM
; command differs from the ROM version in three respects:
;
; - Since we allow array subscripts starting at zero, the size of a dimension
;   will be one more than specified in the DIM statement. E.g. DIM A(10) will
;   create an array of 11 elements.
; - String arrays consist of strings of dynamic length and only contain
;   pointers to strings.
; - The syntax now allows for multiple arrays to be created in one DIM
;   statement, e.g. DIM A(10),B$(10),C(12,13).

DIM_1  RST    #20             ; Loop-back point for multiple DIMs - skip comma
DIM    LD     (23647),HL      ; Main entry point - save CH_ADD in X_PTR
       CALL   LOOKVARS        ; Look up the requested name in VARS area
D_RPC  JP     NZ,#1C8A        ; Report 'Nonsense in BASIC' if not an array name
       JR     C,D_LETTER      ; Skip if DIMensioning a new array
       LD     E,B             ; This code deals with existing arrays which are
       LD     D,#00           ; re-DIM'd - strictly not allowed in BASICODE!
       SBC    HL,DE           ; Step back to first letter of name
       PUSH   HL              ; Save pointer
       CALL   NEXT_ONE        ; Find next variable in HL
       POP    DE              ; Retrieve start address
       PUSH   BC              ; Save BC whilst the existing array is removed
       CALL   #19E5           ; using RECLAIM-1 subroutine
       POP    BC
D_LETTER
       LD     H,#00
       LD     L,B
       LD     (H_LEN),HL      ; Save length of name temporarily in H_LEN
       LD     B,H             ; B counts number of dimensions and is initially
       PUSH   BC              ; zero, C holds first letter of name and type bit
       LD     L,#05           ; HL is initially 5 - number of bytes per element
D_SIZE EX     DE,HL           ; Move HL to DE (Note:label looks redundant here)
D_LOOP RST    #20             ; Move to next dimension size
       LD     H,#FF           ; Set HL high - no limit check needed here
       CALL   INT_EXP         ; Evaluate dimension
       POP    HL              ; Retrieve dimension counter in H
       INC    BC              ; Since subscripts start at zero, increment size
       PUSH   BC              ; by 1 and save it again
       INC    H               ; Increment number of dimensions
       PUSH   HL              ; Save this again
       LD     H,B             ; Transfer current dimension size to HL
       LD     L,C
       CALL   GET_HL          ; Multiply this by running number of elements in
       EX     DE,HL           ; DE and move it to DE again
       RST    #18             ; Get current character
       CP     ","             ; A comma indicates that a next dimension follows
       JR     Z,D_LOOP        ; so loop back
       CP     ")"             ; If no next dimension, check closing bracket -
       JR     NZ,D_RPC        ; report 'Nonsense in BASIC' if absent
       RST    #20             ; Skip past the current character
       POP    BC              ; Now retrieve number of dimensions in B and
       LD     A,C             ; save first character of name and type bit in A
       LD     L,B             ; Transfer number of dimensions to HL
       LD     H,#00
       INC    HL              ; Four extra bytes are required (name end marker,
       INC    HL              ; total array size(2), number of dimensions, plus
       ADD    HL,HL           ; two for each dimension; 2 * (#dimensions + 2)
       ADD    HL,DE           ; Add the size occupied by all elements
       JP     C,#1F15         ; Report 'Out of memory' when overflow
       PUSH   DE              ; Save size of elements
       PUSH   BC              ; Save dimensions and first name of letter
       LD     BC,(H_LEN)      ; Get length of name
       PUSH   HL              ; Save total size excluding name
       ADD    HL,BC           ; Now add the name length (Note: no overflow
       LD     B,H             ; check but unlikely to occur)
       LD     C,L             ; Transfer total size to BC
       LD     HL,(23641)      ; Make space and the end of VARS
       DEC    HL
       CALL   #1655           ; Make room (this will trap any further out of
       INC    HL              ; memory conditions)
       PUSH   DE              ; Save pointer to end of space created
       EX     DE,HL           ; Base address to DE
       LD     HL,(23647)      ; X_PTR points to requested name
       LD     (DE),A          ; Set first byte of name
D_CHAR INC    DE              ; Now copy the other characters of the name
D_SP   INC    HL
       LD     A,(HL)
       CP     #21
       JR     C,D_SP          ; But ignore any spaces and control codes
       OR     #20             ; Convert all but first character to lower case
       LD     (DE),A
       CALL   #2C88           ; Check for alphanumeric character
       JR     C,D_CHAR        ; Loop back for all characters of the name
       EX     DE,HL           ; Swap pointers
       LD     (HL),#00        ; Set end marker of name
       POP    DE              ; Retrieve pointer to last byte of array
       POP    BC              ; Total size excluding name
       DEC    BC              ; Reduce this by three (exclude the name's end
       DEC    BC              ; marker and two bytes containing the size of
       DEC    BC              ; the array
       INC    HL
       LD     (HL),C          ; Set array size
       INC    HL
       LD     (HL),B
       POP    AF              ; Retrieve number of dimensions in A
       INC    HL
       LD     (HL),A          ; Enter number of dimensions
       LD     H,D             ; Copy end address to HL
       LD     L,E
       DEC    DE              ; Step one byte down
       LD     (HL),#00        ; Now clear the array's contents by copying the
       POP    BC              ; zero byte from the end down to the start
       LDDR
D_SZ   POP    BC              ; For each dimension, retrieve its size in BC
       LD     (HL),B          ; and enter it into the array's space
       DEC    HL
       LD     (HL),C
       DEC    HL
       DEC    A               ; Decrease the dimension counter
       JR     NZ,D_SZ         ; Loop for all dimensions
       RST    #18             ; Get current character
       CP     ","             ; If it's a comma, loop back to handle more
       JP     Z,DIM_1         ; arrays
       RET                    ; Done

; Interrupt service front-end
; This is a bodge which re-activates our interpreter after it has been disabled
; (usually after a command processed by an external ROM, e.g. Interface 1 or other
; storage system). These systems have the habit of jumping back to the Spectrum
; ROM's main loop, thereby disabling our interpreter.
; When this happens, the Spectrum ROM's editor is eventually entered and will wait
; for a key to be pressed. At this point, we'll intercept the return address at 
; $0F3B (ED_LOOP+3) and replace it with our equivalent. We'll do the same with
; ED_ERROR and MAIN_3 so when the call to WAIT_KEY at ED_LOOP returns we are back
; in control. A nice piece of ROP back in the '80s!
; To make this work, an interrupt vector table has been set up at locations
; $FE00-$FF00 (inclusive!) with 257 bytes holding $FD and the Z80 put in interrupt
; mode (IM) 2. In this mode, it will read the address to be jumped to from the I
; register (high byte) and a byte put on the data bus when the interrupt occurs.
; The latter byte is usually $FF but to be on the safe side we'll use a whole page
; of precious RAM. The Z80 will then jump to $FDFD which contains a JP to the code
; below.

INTSRV PUSH   AF
       LD     A,(0)           ; check first byte of ROM
       CP     #F3             ; it is F3 with Spectrum ROM paged in
       JR     NZ,INTEND       ; if not, exit early
       PUSH   HL              ; Save HL
       LD     HL,(23613)      ; ERR_SP
       DEC    HL              ; Check address below ERR_SP
       LD     A,(HL)          ; for $0F3B (ED_LOOP+3)
       CP     #0F
       JR     NZ,NO_ED
       DEC    HL
       LD     A,(HL)
       CP     #3B
       JR     NZ,NO_ED        ; Exit if not in ROM's editor
       PUSH   DE              ; Save DE
       LD     DE,ED_LOOP+3    ; Replace address with our ED_LOOP+3
       LD     (HL),E
       INC    HL
       LD     (HL),D
       INC    HL
       LD     DE,ED_ERROR     ; Also replace ED_ERROR (it's next on the stack)
       LD     (HL),E
       INC    HL
       LD     (HL),D
       INC    HL
       INC    HL              ; Step past saved address of ERR_SP
       INC    HL
       LD     DE,MAIN_3       ; Next, replace address of MAIN_3
       LD     (HL),E
       INC    HL
       LD     (HL),D
       POP    DE              ; Restore registers
NO_ED  POP    HL
INTEND POP    AF
       JP     #0038           ; Jump to ROM handler's code

; The interrupt vector itself

       ORG    #FDFD
       JP     INTSRV

; locations $FE00-$FF00 inclusive hold the interrupt vector $FDFD
; (see above for explanation)

; locations $FF01-$FF40 hold a table used by FN EOF
; For each of the 16 available streams:
; - byte 00: flag; 00=no pending input, $FF pending input
; - byte 01: byte pending to be read next
; - bytes 02-03: address of original input subroutine

; A message from the author: v2.02, built at 8 June 1987.

       ORG    #FF41
       DEFM   " 2.02  080687  JB "

; Two variables

       ORG    65365
       DEFW   1000          ; Start line# of BASICODE program
BRKFLG DEFB   0             ; 0: Break enabled, <>0 disabled
