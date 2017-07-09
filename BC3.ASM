; BASICODE-3 v3.1 FOR THE ZX SPECTRUM 48K
; Copyright (C) 1985-2017 by JAN BREDENBEEK, HILVERSUM, THE NETHERLANDS
; RELEASED UNDER GNU v3 PUBLIC LICENSE, 2017

; TRANSLATION & TAPE ROUTINES
; REVISION 1.0: 21 DECEMBER 1985
; REVISION 2.0: 16 OCTOBER 1986
; REVISION 3.0: 16 APRIL 1987
; REVISION 3.1: 8 JUNE 1987
; REVISION 4.0: 25 MARCH 2016


; ROM routines

NUMERI EQU    #2D1B
ALPHA  EQU    #2C8D
ALPHAN EQU    #2C88
MAKERO EQU    #1655		; MAKE_ROOM
ONE_SP EQU    #1652		; id. with 1 byte
RECLAI EQU    #19E8		; RECLAIM
EDGE1  EQU    #05E7		; LD_EDGE_1 
EDGE2  EQU    #05E3		; LD_EDGE_2

BASIC  EQU    59450		; Start of extended BASIC interpreter
LN_ADD EQU    BASIC+12	; Hook into LN_ADD routine
OUT_LI EQU    BASIC+18	; Hook into OUT_LINE routine
BASERR EQU    #0053		; Equivalent of RST 8 but no ROM paging
BCSTRT EQU    #FF55		; Location normally contains 1000 but can be POKEd
ATTR_P EQU    23695
STX    EQU    88		; We will abuse MEMBOT temporarily as flags location

       ORG    53950           ; Start of code
       JP     ROPEN           ; Entry point for OPEN BC3-file for read
       JP     WOPEN           ; Id. for WRITE
       JP     CLOSE           ; CLOSE BC3-file

; The following text forms the BASICODE-3 menu as it appears when "*" is
; entered from BASIC. This has the following form:

; DEFW LENGTH
; DEFM "text" (last character has bit 7 set)
; DEFB #01    (marker byte)
; DEFW CHECKSUM

; The start address is stored in the EXTVEC location of BASIC. If the checksum
; is correct BASIC will make a call to the address immediately after the
; checksum on encountering a "*" command.
                               
       DEFW   SIGNEND-SIGNON   ; Length
SIGNON DEFB   #80              ; Initial byte needed for Spectrum's PO_MSG
       DEFM   "**BASICODE-3 LOAD & SAVE PROGRAM V3.1**"
       DEFB   #0D,#0D
       DEFM   "Options:"
       DEFB   #0D,#0D
       DEFM   "*L: LOAD BASICODE program"
       DEFB   #0D
       DEFM   "*T: Translate BASICODE program"
       DEFB   #0D
       DEFM   "*K: LIST BASICODE program"
       DEFB   #0D
; *** 20160326 Added *P option (=*K to channel #3)
       DEFM   "*P: LIST to Printer"
       DEFB   #0D
; *** 20160326 END
       DEFM   "*C: Convert program to BASICODE"
       DEFB   #0D
       DEFM   "*W: SAVE program in BASICODE"
       DEFB   #0D
       DEFM   "*S: SAVE translated program"
       DEFB   #0D
       DEFM   "*B: Backup translation program"
       DEFB   #0D
       DEFM   "<ENTER>: Back to BASIC"
       DEFB   #0D,#0D
       DEFB   ">"+#80
SIGNEN DEFB   #01
       DEFW   23130            ; The checksum

; Start of BASICODE-3 menu code
                               
       RST    #18              ; Get char immediately after the "*"
       CALL   #2048            ; Zero flag set if end of statement
       PUSH   AF               ; Save char
       LD     DE,#0200         ; If not at end of stmt, call EACH_STMT to
       CALL   NZ,#198B         ; find the end
       POP    AF               ; Restore char
       CALL   CHECK            ; Check if it is a valid command, if so jump
                               ; to the command routine, if not continue
MENU   CALL   #0D6B            ; Clear the screen
       LD     A,#02            ; Select channel #2
       CALL   #1601
       LD     DE,SIGNON
       XOR    A
       CALL   #0C0A            ; Display the menu
       RES    5,(IY+1)         ; Signal "no key pressed"
       CALL   #15DE            ; Fetch key
       CP     #0D              ; ENTER?
       RET    Z                ; Yes, return to BASIC
       PUSH   AF               ; If not, clear screen
       CALL   #0D6B
       POP    AF
       CALL   CHECK            ; Now check for command, loop back if invalid
       JR     MENU

CHECK  AND    #DF              ; Convert any lowercase to uppercase
       POP    HL               ; Get return address
       CP     "L"              ; Check for "LOAD"
       JP     Z,LDPROG
       CP     "T"
       JP     Z,TRANSLATE      ; "TRANSLATE"
       CP     "K"
       JP     Z,LIST           ; "LIST"
; *** 20160326 Added P Option
       CP     "P"
	   JP     Z,PLIST
; *** 20160326 END
       CP     "C"
       JP     Z,CONVERT        ; "CONVERT"
       CP     "W"
       JP     Z,SVPROG         ; "WRITE"
       CP     "S"
       JR     Z,SAVE           ; "SAVE"
       CP     "B"
       JR     Z,BACKUP         ; "BACKUP"
       JP     (HL)             ; If no valid command, return

; SAVE and BACKUP handled by BASIC routines
                               
SAVE   LD     HL,980           ; SAVE enters at line 980
       JR     EX_BAS
BACKUP LD     HL,960           ; BACKUP at 960
EX_BAS LD     D,1              ; Signal "statement #1"
       JP     #1E73            ; Jump to GO-TO subroutine

; The keywords table. Each entry consists of the Spectrum token code followed
; by the (BASICODE) ASCII of the keyword. LEFT$, MID$, RIGHT$ and ON have
; alternative codes #80 to #83.
                               
TKBAS  DEFB   #C7
       DEFM   "<="
       DEFB   #C9
       DEFM   "<>"
       DEFB   #C8
       DEFM   ">="
       DEFB   #BD
       DEFM   "ABS"
       DEFB   #C6
       DEFM   "AND"
       DEFB   #AF
       DEFM   "ASC"
       DEFB   #B7
       DEFM   "ATN"
       DEFB   #C2
       DEFM   "CHR$"
       DEFB   #B3
       DEFM   "COS"
       DEFB   #E4
       DEFM   "DATA"
       DEFB   #CE
       DEFM   "DEFFN"
       DEFB   #E9
       DEFM   "DIM"
       DEFB   #E2
       DEFM   "END"
       DEFB   #B9
       DEFM   "EXP"
       DEFB   #A8
       DEFM   "FN"
       DEFB   #EB
       DEFM   "FOR"
       DEFB   #ED
       DEFM   "GOSUB"
       DEFB   #EC
       DEFM   "GOTO"
       DEFB   #FA
       DEFM   "IF"
       DEFB   #EE
       DEFM   "INPUT"
       DEFB   #BA
       DEFM   "INT"
       DEFB   #80
TKLEFT DEFM   "LEFT$"
       DEFB   #B1
       DEFM   "LEN"
       DEFB   #F1
       DEFM   "LET"
       DEFB   #B8
       DEFM   "LOG"
       DEFB   #81
TKMID  DEFM   "MID$"
       DEFB   #F3
       DEFM   "NEXT"
       DEFB   #C3
       DEFM   "NOT"
       DEFB   #83
       DEFM   "ON"
       DEFB   #C5
       DEFM   "OR"
       DEFB   #F5
       DEFM   "PRINT"
       DEFB   #E3
       DEFM   "READ"
       DEFB   #EA
       DEFM   "REM "
       DEFB   #E5
       DEFM   "RESTORE"
       DEFB   #FE
       DEFM   "RETURN"
       DEFB   #82
TKRGHT DEFM   "RIGHT$"
       DEFB   #F7
       DEFM   "RUN"
       DEFB   #BC
       DEFM   "SGN"
       DEFB   #B2
       DEFM   "SIN"
       DEFB   #BB
       DEFM   "SQR"
       DEFB   #CD
       DEFM   " STEP"
       DEFB   #E2
       DEFM   "STOP"
       DEFB   #AD
       DEFM   "TAB"
       DEFB   #B4
       DEFM   "TAN"
       DEFB   #CB
       DEFM   " THEN"
       DEFB   #CC
       DEFM   " TO"
       DEFB   #B0
       DEFM   "VAL"
       DEFB   #FF
TK_END EQU    $

; The "LOAD" command. This loads the BASICODE-3 program in its ASCII form
; into free memory starting at (STKEND)+100
                               
LDPROG LD     (IY+STX),#82     ; Signal "look for (STX+80) char"
       LD     BC,(BCSTRT)      ; Fetch start line number (usually 1000)
       CALL   LN_ADDR          ; Find its address
       LD     (HL),#FF         ; Store program end marker
       INC    HL
       LD     (23627),HL       ; Reset VARS
       EX     DE,HL
       LD     HL,(23641)
       DEC    HL
       CALL   #19E5            ; Reclaim whole VARS area
       LD     HL,-200
       ADD    HL,SP            ; Find addr 200 locations below SP
       LD     DE,(23653)
       SBC    HL,DE            ; Subtract STKEND from it, this yields the
       LD     B,H              ; amount of memory available for the program
       LD     C,L              ; to be loaded; pass it to BC
       ADD    HL,DE            ; Restore HL
       JR     NC,MEM_OK        ; Jump if OK, else report "Out of memory"
       RST    8
       DEFB   #03
MEM_OK LD     DE,101           ; Store ETX marker at (SP-100)
       ADD    HL,DE
       LD     (HL),#03
       DEC    HL
       LD     D,H
       LD     E,L
       DEC    DE
       INC    BC
       LD     (HL),#00
       LDDR                    ; Now clear whole area (needed for load routine)
       LD     (BCPROG),HL      ; Store start addr
       CALL   LDBLOCK          ; Load the program
       JP     NC,TP_ERR        ; If error, report it.
       RET                     ; *** 20160325: RET added so *L command returns after succesful load

; TRANSLATE program from BASICODE to Spectrum BASIC
                               
TRANSLATE
       CALL   #0D6B            ; Clear screen
       LD     HL,(BCSTRT)      ; Fetch start line number (usually 1000)
       DEC    HL
       LD     (LASTNR),HL      ; Store start line -1 as last line
       LD     HL,(BCPROG)      ; Fetch program start
       LD     A,(HL)           ; If no STX at start, no program loaded
       CP     #82              ; so return
       RET    NZ
       INC    HL               ; Step past the STX and initial CR
       INC    HL
       LD     (LNPTR),HL       ; Store pointer to first line

; The main loop for each line
                               
NXTLIN CALL   #1F54            ; Test BREAK key
       JR     C,CLRWRK         ; Skip if not pressed
       LD     HL,(LNPTR)       ; Else, store STX at start of next line - 2
       DEC    HL               ; and update BCPROG so that the translation
       DEC    HL               ; continues at the next line when another
       LD     (BCPROG),HL      ; *T command is given
       LD     (HL),#82
       RST    8                ; Stop with "BREAK into program" report
       DEFB   #14
CLRWRK CALL   #16BF            ; Clear workspace
       LD     BC,1             ; Enter one CR into new workspace
       RST    #30
       LD     (HL),#0D
       LD     (23643),HL       ; Update K_CUR
       LD     HL,(LNPTR)       ; Fetch address of next line to be translated
       LD     A,(HL)           ; But return if ETX reached
       CP     #83
       RET    Z

; First the line number is read. If the line number encountered is less than
; that of the previous line, it is rejected and the number of the previous
; line + 1 used. This is to prevent lines being entered with numbers out of
; order (due to transmission errors) which would confuse the Spectrum BASIC's
; editor. Of course, if a transmission error leads to a line number much
; higher than its predecessor (e.g. 20000 instead of 2000) then all line
; numbers after it would be scrambled. However this case is much less likely
; to occur than the former case.
                               
       LD     BC,0             ; Initialise BC to zero
NXTDGT LD     A,(HL)           ; Read next digit
       SUB    #30              ; Subtract code for "0"
       CP     #0A              ; If no digit code, jump out of loop
       JR     NC,NUMEND
       EX     DE,HL            ; Save pointer in DE
       LD     H,B              ; Copy number to HL
       LD     L,C
       ADD    HL,HL            ; Multiply by four
       ADD    HL,HL
       ADD    HL,BC            ; Add original number so HL is now 5*BC
       ADD    HL,HL            ; Double again so now HL=10*BC
       EX     DE,HL            ; Number to DE, pointer to HL
       INC    HL               ; Step to next character
       LD     B,D              ; High byte of number to B
       ADD    A,E              ; Add new digit
       LD     C,A              ; Low byte to C
       JR     NC,NXTDGT        ; Loop back if no carry, else increase B
       INC    B
       JR     NXTDGT
NUMEND EX     DE,HL            ; End of loop; save pointer in DE
       BIT    7,B              ; If line number >32768, reject it
       JR     Z,NR_OK
       LD     BC,#0000
NR_OK  LD     HL,(LASTNR)      ; Fetch last line number
       SBC    HL,BC            ; Compare with new
       JR     C,ST_NO          ; If new number is higher, it is OK
       ADD    HL,BC            ; Else, restore last line number and use
       INC    HL               ; it increased by 1 for the current line number
       LD     B,H
       LD     C,L
ST_NO  LD     (LASTNR),BC      ; Store new line number
       PUSH   DE               ; Save pointer
       LD     A,#FF            ; Select channel -1; any character "printed"
       CALL   #1601            ; to it will be added to the workspace
       POP    HL               ; Restore pointer
       DEC    HL               ; Balance the "INC" below

; Start of loop for each character
                               
TRLOOP INC    HL               ; Step to next character
       LD     A,(HL)           ; Fetch its code
       CP     #0D              ; End of line reached?
       JR     Z,PASS2          ; Jump if so
       CP     #21              ; Ignore spaces and other codes below #20
       JR     C,TRLOOP
       CP     #22              ; Quote character?
       JR     NZ,NOT_Q         ; Skip if not
QLOOP  RST    #10              ; This loop copies every character within
QNEXT  INC    HL               ; quotes to the translated line
       LD     A,(HL)
       CP     #0D              ; But exit if CR encountered
       JR     Z,M_QUOTE
       CP     #20              ; Ignore other control codes
       JR     C,QNEXT
       CP     #22              ; Exit when closing quote encountered
       JR     Z,NOT_Q
       JR     QLOOP
M_QUOT LD     A,#22            ; When CR encountered within quotes, add the
       RST    #10              ; missing closing quote (common programming
       JR     PASS2            ; error) and exit

; Now look for tokens
                               
NOT_Q  LD     DE,TKBAS         ; Base of token table
TK_NXT PUSH   HL               ; Save program pointer
       LD     A,(DE)           ; Fetch token code from table
       LD     B,A              ; Copy it to B
       INC    A                ; But jump if end marker (#FF) reached
       JR     Z,TK_NOTF
TK_CHR INC    DE               ; Fetch next character of token
       LD     A,(DE)           ; But skip if end of token reached
       CP     #80
       JR     NC,TK_FOUND
       CP     #20              ; Ignore spaces in the token table entry
       JR     Z,TK_CHR
       CP     (HL)             ; Now compare with current program char
       INC    HL               ; Bump pointer for next char
       JR     Z,TK_CHR         ; Loop back as long as the characters match
       JR     NC,TK_NOTF       ; If table entry alphabetically higher, exit
TK_SKI INC    DE               ; Skip the remaining token characters
       LD     A,(DE)
       RLCA                    ; Bit 7 set marks start of new token
       JR     NC,TK_SKIP
       POP    HL               ; Restore pointer to program
       JR     TK_NXT           ; Loop back

; Token not found so simply add new character to workspace.
                               
TK_NOT POP    HL               ; Restore pointer
       LD     A,(HL)           ; Fetch character
       RST    #10              ; Add it to the translated line
       JR     TRLOOP           ; Loop back for next

; If token found the token code is added to the workspace, but some tests have
; to be made for LEFT$/MID$/RIGHT$ and REM.

TK_FOU LD     A,B              ; Fetch token code
       POP    BC               ; Fetch pointer to start of token in line
       DEC    HL               ; Point to the last token character in the line
       CP     #83              ; Is it LEFT$/MID$/RIGHT$?
       JR     NC,NOT_LMR       ; No, skip
       LD     A,#A8            ; These three tokens are replaced by FN LEFT$/
       RST    #10              ; MID$/RIGHT$, so add FN token followed by
LMR_LP LD     A,(BC)           ; characters of token
       INC    BC
       RST    #10
       CP     "$"
       JR     NZ,LMR_LP
       JR     TRLOOP           ; Loop back
NOT_LM RST    #10              ; Add token code to workspace
       CP     #EA              ; Is it "REM"?
       JR     NZ,TRLOOP        ; Jump if not
LN_IGN INC    HL               ; Else, copy all characters after REM without
       LD     A,(HL)           ; interpreting them
       CP     #0D
       JR     Z,PASS2
       CP     #20              ; However skip control codes other than CR
       JR     C,LN_IGN
       RST    #10
       JR     LN_IGN

; Start of second pass. This has three functions:

; Adds a "LET" token to each assignment statement;
; Converts "IF x THEN line number" to "IF x THEN GO TO line number";
; Converts "ON x GOTO/GOSUB a,b,c,.." to "GOTO/GOSUB *x;a,b,c,.."
                               
PASS2  INC    HL               ; Step past CR in program
       LD     (LNPTR),HL       ; Store start addr of next line
       LD     HL,(23649)       ; Fetch start of workspace
       CALL   INSERT           ; Insert a LET if needed
P2_LOO LD     A,(HL)           ; Fetch each character of the line
       INC    HL
       CP     #0D              ; Jump when at end
       JR     Z,P2_END
       CP     #EA              ; Also jump when REM encountered
       JR     Z,P2_END
       CP     #22              ; Skip unless quote encountered
       JR     NZ,TST_INS
SK_QUO LD     A,(HL)           ; Skip each character within quotes
       CP     #0D              ; Can happen in quotes?
       JR     Z,P2_END
       INC    HL
       CP     #22
       JR     NZ,SK_QUOTE
       JR     P2_LOOP
TST_IN CP     ":"              ; New statement reached?
       JR     Z,CALLIT         ; Yes, jump
       CP     #CB              ; Is it "THEN"?
       JR     NZ,TST_ON        ; No, skip
CALLIT CALL   INSERT           ; Insert LET or GO TO as appropriate
       JR     P2_LOOP          ; Loop back
TST_ON CP     #83              ; Is it "ON"?
       JR     NZ,P2_LOOP       ; Loop back if not
       CALL   ONE_SPACE        ; Make room for one extra character
       EX     DE,HL            ; Save pointer to ON token in DE
       LD     (HL),"*"         ; Insert a "*" character
ON_LOO INC    HL               ; Now enter a loop to find the GOTO/GOSUB
       LD     A,(HL)
       CP     #0D              ; But exit if CR reached (error)
       JR     Z,P2_END
       CP     #EC              ; Test for "GOTO"
       JR     Z,ON_SC
       CP     #ED              ; Test for "GOSUB"
       JR     NZ,ON_LOOP
ON_SC  LD     (HL),";"         ; Replace GOTO/GOSUB by semicolon
       LD     (DE),A           ; Enter GOTO or GOSUB at start of statement
       JR     P2_LOOP          ; Loop back

; End of pass 2; the line is now entered into the program area
                               
P2_END LD     HL,(23651)       ; Find the length of the line by subtracting
       LD     DE,(23649)       ; WORKSP from STKBOT
       AND    A
       SBC    HL,DE
       PUSH   HL               ; Save length
       INC    HL               ; Increase it by 4 to allow for the line number
       INC    HL               ; and line length bytes
       INC    HL
       INC    HL
       LD     B,H              ; Pass it to BC
       LD     C,L
       LD     HL,(23627)       ; Make new room before VARS
       DEC    HL
       CALL   MAKEROOM
       LD     HL,(23651)       ; Point to last character of line
       DEC    HL
       POP    BC               ; Get a copy of the original line length
       PUSH   BC
       LDDR                    ; Copy the line into the program area
       POP    BC               ; Get line length
       LD     HL,(LASTNR)      ; And line number
       EX     DE,HL            ; Pass this to DE and pointer to HL
       LD     (HL),B           ; The line length is entered
       DEC    HL
       LD     (HL),C
       DEC    HL
       LD     (HL),E           ; Followed by the line number
       DEC    HL
       LD     (HL),D
       PUSH   HL
       LD     A,#02            ; Select stream 2
       CALL   #1601
       POP    HL
       LD     (IY+82),#FF      ; Suppress scroll prompt
       CALL   OUT_LINE         ; Display the line now
       RST    #10              ; Print final CR
       JP     NXTLIN           ; Loop back for next line

; The following subroutine inserts a LET or GO TO token as appropriate.
                               
INSERT LD     A,(HL)           ; Fetch current character
       SUB    #30              ; Is it a digit?
       CP     #0A
       LD     C,#EC            ; Load C with "GO TO" token code
       JR     C,MK_SPC         ; Jump if digit
       LD     C,#F1            ; Load C with "LET" token code
       SUB    #11              ; Test for uppercase letter
       CP     #1A
       RET    NC               ; Return if no letter, no insertion needed
MK_SPC LD     A,C              ; Pass the token code to A whilst one space is
       CALL   ONE_SPACE        ; made
       INC    HL
       LD     (HL),A           ; Finally enter the token code and return
       RET

; The *K command.
                               
LIST   LD     A,#02            ; Select stream #2 for "K"
; *** 20160326 Added "P" option
       JR     LIST_2
PLIST  LD     A,#03            ; Select stream #3 for "P"
; *** 20160326 END
LIST_2 CALL   #1601
       LD     HL,(BCPROG)      ; Fetch start of untranslated program
       LD     A,(HL)
       CP     #82
       RET    NZ               ; Return if no program present
L_LOOP INC    HL               ; Print each character until ETX found
       LD     A,(HL)
       CP     #83
       RET    Z
       CP     #0D
       JR     Z,L_PRINT
       CP     #20
       JR     NC,L_PRINT
       LD     A,#8F            ; However replace control codes by CHR$(143)
L_PRIN RST    #10
       JR     L_LOOP

; The *C-command. This uses some flag bits in MEMBOT (23698). Bit 0 indicates
; original BASIC program overwritten, bit 1 signals "in REM statement", bit 2
; signals "last character was THEN", bit 3 is set during ON-GOTO/GOSUB
; processing and bit 4 is set during line number conversion.
; Location 23699 is used as a quote counter.

; Hooks into the BASIC interpreter
MAIN_9 EQU    BASIC+15			
O_NUM1 EQU    BASIC+21


X_PTR  EQU    23647
K_CUR  EQU    23643

; Error message for the *C(onvert) command

ERRMSG DEFB   #80
       DEFM   "*ERROR*"
LENMSG DEFB   #8D
       DEFM   "Line too long at line"
OVWMSG DEFB   #A0
       DEFM   "BASIC PROGRAM OVERWRITTEN"
       DEFB   #8D

CONVER LD     BC,(BCSTRT)      ; Fetch start line number and calculate its
       CALL   LN_ADDR          ; address
       LD     (START),HL       ; Store this into START
	   
; Now enter the first pass to do some sanity checks on the BASIC program
	   
NEXTLN LD     A,(HL)
       INC    A
       JP     Z,CONV	; FF in first byte signals end of program
       LD     (LNPTR),HL
       LD     D,(HL)
       INC    HL
       LD     E,(HL)
       LD     (LASTNR),DE
       INC    HL
       INC    HL
       INC    HL
NXTCHR LD     A,(HL)
       INC    HL
       CP     #0D
       JR     Z,NEXTLN	; end of line, skip to next
       CP     #7F
       JR     C,NXTCHR	; everything below #7F is OK
       CP     #A5
       JR     C,ERROR	; block graphics and UDG
       CP     #E2
       JR     Z,ERROR	; STOP is illegal in Basicode-3
       CP     #F7
       JR     Z,ERROR	; and so is RUN
       CP     #C5
       JR     Z,AND_OR	; AND and OR need brackets
       CP     #C6
       JR     Z,AND_OR
       CP     #C3
       JR     NC,COMMND
       CP     #A8
       JR     Z,NXTCHR	; FN
       CALL   CKBRAC
COMMND PUSH   HL
       LD     HL,TKBAS
       LD     BC,TK_END-TKBAS
       CPIR		; check if command is in table
       POP    HL
       JP     PE,NXTCHR
       JR     ERROR
AND_OR CALL   CKBRAC	; check if function calls have brackets
       DEC    HL
       DEC    HL
       LD     A,(HL)
       INC    HL
       CP     ")"
       JR     NZ,ERROR
       INC    HL
       JR     NXTCHR
CKBRAC LD     C,A
       LD     A,(HL)
       CP     "("
       LD     A,C
       RET    Z
	   
; Syntax error so display error message and stop	   
	   
ERROR  LD     (23647),HL
       RES    5,(IY+55)
       CALL   #0D6E
       SET    5,(IY+2)
       LD     DE,ERRMSG
       CALL   #0C0A
       LD     HL,(LNPTR)
       CALL   OUT_LINE
       LD     HL,(LASTNR)
       LD     (23625),HL
       XOR    A
       LD     (23648),A
       CALL   #16B0
       CALL   #1097
       LD     SP,(23613)
       POP    BC
       JP     MAIN_9

; No obvious syntax errors so continue	   
	   
CONV   CALL   #16BF		; clear WORKSP
       LD     BC,101
       RST    #30		; make room for 101 bytes
       LD     (K_CUR),HL
       LD     A,#FF
       CALL   #1601		; open stream for printing to WORKSP
       LD     HL,(23633)
       LD     DE,ADDCHR	; modify handler address
       LD     (HL),E
       INC    HL
       LD     (HL),D
       LD     HL,(START)
       DEC    HL
       XOR    A
;       LD     (CHECKS),A	; *** 20160325: Removed
       LD     (23698),A
       LD     A,#82
       RST    #10		; start with STX char
	   
; Now loop for each line to "print" it into WORKSP area in BASICODE form
	   
NEWLIN LD     A,#0D		; End-of-line marker
       RST    #10
       XOR    A
       LD     (L_LEN),A	; Line length
       LD     (23699),A	; Quote counter
       RES    1,(IY+88)	; Not in REM
       RES    3,(IY+88)	; Not in ON..GOTO/GOSUB
       INC    HL
       LD     (LASTLN),HL	; Set last line ptr
       LD     B,(HL)
       INC    HL
       LD     C,(HL)	; Line number to BC
       LD     A,B
       INC    A
       JP     Z,END		; FFH marks end of program
       LD     (LASTNR),BC	; Set last line number
       INC    HL
       INC    HL
       LD     (X_PTR),HL	; Save HL
       SET    4,(IY+88)
       CALL   O_NUM1	; Now print line number
       RES    4,(IY+88)
       LD     HL,(X_PTR)
       LD     A,#20		; followed by space
	   
; Loop for each character in a line
	   
NEWPRT RST    #10		; Output character
NEWCHR INC    HL
       LD     A,(HL)	; Get next
       CP     #0D
       JR     Z,NEWLIN	; end of line
       CP     #20
       JR     C,NEWCHR	; skip control codes
       JR     NZ,TST_Q	; and spaces except in quotes and REM statements
       BIT    1,(IY+88)
       JR     NZ,NEWPRT	; in REM statement
       BIT    0,(IY+89)
       JR     Z,NEWCHR	; not in quotes
TST_Q  CP     #22
       JR     NZ,CKSEMI
       INC    (IY+89)	; increase counter for each quote; only bit 0 is tested
CKSEMI CP     ";"
       JR     NZ,TSTTOK	; might be in ON statement
       BIT    3,(IY+88)
       JR     Z,NEWPRT
       BIT    0,(IY+89)
       JR     NZ,NEWPRT	; but not in REM or quotes
       LD     A,#20
       RST    #10
       LD     A,(ON_CHR)	; fetch GOTO or GOSUB token
       RES    3,(IY+88)	
       JR     PR_TOK
TSTTOK CP     #A5		; test for tokens
       JR     NC,TOKEN
       CALL   ALPHA
       JR     NC,NEWPRT	; Print and next char if alpha
       BIT    0,(IY+89)	; ... and in quotes
       JR     NZ,NEWPRT
       BIT    1,(IY+88)	; ... and in REM
       JR     NZ,NEWPRT
       AND    #DF		; else, force uppercase
       JR     NEWPRT
TOKEN  CP     #A8		; "FN"
       JR     NZ,TSTLET
       LD     DE,TKLEFT	; Handle FN LEFT$/MID$/RIGHT$
       CALL   CMPSTR
       JR     C,NEWCHR
       LD     DE,TKMID
       CALL   CMPSTR
       JR     C,NEWCHR
       LD     DE,TKRGHT
       CALL   CMPSTR
       JR     C,NEWCHR
TSTLET CP     #F1		; Suppress "LET"
       JR     Z,NEWCHR
       CP     #EC
       JR     Z,GOTO
       CP     #ED
       JR     Z,GOTO	; Jump with GOTO and GOSUB
PR_TOK EX     DE,HL
       LD     HL,TKBAS
       LD     B,A
       CPIR		; Look up token in table
       EX     DE,HL
PRTOK1 LD     A,(DE)
       CP     #80
       JR     NC,PRTOK2
       RST    #10		; Print each character of token
       INC    DE
       JR     PRTOK1
PRTOK2 LD     A,(HL)			
       CP     #CB
       JR     Z,THEN	; Jump with "THEN"
       CP     #EA
       JR     NZ,NEWCH1
       SET    1,(IY+88)	; Set bit 1 if in REM statement
       JR     NEWCH1
THEN   SET    2,(IY+88)	; ... and bit 2 after "THEN"
NEWCH1 JP     NEWCHR	; Loop back

; Handle ON..GOTO and ON..GOSUB 
; These are written as GOTO/GOSUB *expr; line1,line2,.. in extended Spectrum Basic
; and need to be converted to ON expr GOTO/GOSUB line1,line2,..

GOTO   PUSH   HL		; First determine if it's a normal GOTO/GOSUB or indeed ON
G_NOSP INC    HL
       LD     A,(HL)		
       CP     #0D
       JR     Z,NOT_ON	; end of line reached, not ON case
       CP     #21
       JR     C,G_NOSP	; skip spaces and control chars
       CP     "*"
       JR     Z,ON		; if asterisk found we have an ON case
NOT_ON POP    HL
       LD     A,(HL)
       CP     #EC
       JR     NZ,PR_TOK	; Jump unless dealing with GOTO
       BIT    2,(IY+88)	; After "THEN"?
       JR     Z,PR_TOK	; no, print GOTO
       JR     NEWCH1	; but suppress GOTO after THEN
ON     POP    DE		; Now deal with ON
       LD     A,(DE)
       LD     (ON_CHR),A	; Save GOTO or GOSUB token
       SET    3,(IY+88)	; Signal "in ON statement"
       LD     A,"O"
       RST    #10
       LD     A,"N"
       RST    #10		; Output "ON" and loop back
       JR     NEWCH1
	   
; Add character to BASIC line in WORKSP (called by RST 10H when channel "R" opened)
	   
ADDCHR CALL   #0F81		; call routine in ROM to enter character
       RES    2,(IY+88)	; Reset "THEN" flag
; *** 20160325: Code removed as the checksum is now handled by SVBLOCK routine
;       LD     HL,CHECKS
;       OR     #80		; Set bit 7 before updating checksum
;       XOR    (HL)
;       LD     (HL),A
;       INC    HL
       LD     HL,L_LEN	; *** Now point to L_LEN
; *** 20160325: End of modification
       INC    (HL)		; Increase line length counter
       LD     A,61
       CP     (HL)
       JR     NC,TSTFULL	; Jump unless >60 chars
       LD     (HL),#00
       LD     A,#02		; Open channel 2
       LD     (23692),A	; Reset scroll counter
       CALL   #1601
       LD     DE,LENMSG
       XOR    A
       CALL   #0C0A		; Print "Line too long at line" message
       LD     BC,(LASTNR)
       CALL   O_NUM1	; followed by line number
       LD     A,#0D
       RST    #10
       LD     A,#FF		; Re-open channel "R"
       CALL   #1601
TSTFUL LD     HL,(K_CUR)	; Test if still > 100 bytes available
       LD     DE,100
       ADD    HL,DE
       JR     C,FULL
       SBC    HL,SP
       RET    C		; Return if enough memory
FULL   LD     DE,(START)
       LD     HL,(LASTLN)
       CALL   #19DD
       BIT    4,(IY+88)
       JR     NZ,RECPRG
       PUSH   BC
       EXX
       POP    BC
       AND    A
       SBC    HL,BC
       EXX
RECPRG CALL   #19E8
       LD     (LASTLN),HL
       SET    0,(IY+88)
       LD     HL,(K_CUR)
       LD     DE,100
       ADD    HL,DE
       JR     C,BADMEM
       SBC    HL,SP
       RET    C
BADMEM CALL   RST_CH
       JP     #1F15

CMPSTR PUSH   HL		; Compare strings
CMPSLP INC    HL
       LD     A,(HL)
       CP     #21
       JR     C,CMPSLP
       LD     A,(DE)
       RLCA
       RRCA
       JR     C,CMPEND
       INC    DE
       XOR    (HL)
       AND    #DF
       JR     Z,CMPSLP
CMPEND POP    HL
       LD     A,(HL)
       RET

; End of Spectrum-to-Basicode translation
	   
END    XOR    A
       LD     (L_LEN),A
       LD     A,#83
       RST    #10		; Output ETX char
; *** 20160325: Removed as this is now handled by SVBLOCK routine
;       LD     A,(CHECKS)
;       RST    #10		; Followed by checksum byte
; *** 20160325: END
       LD     HL,(23649)
       LD     DE,100
       ADD    HL,DE
       LD     (BCPROG),HL
RST_CH LD     HL,(23633)
       LD     (HL),#81
       INC    HL
       LD     (HL),#0F	; Restore original address of "R" channel handler
       LD     A,#02
       CALL   #1601
       XOR    A
       LD     DE,OVWMSG
       BIT    0,(IY+88)
       RET    Z					
       CALL   #0C0A		; if bit 0 set, display "BASIC PROGRAM OVERWRITTEN"
       LD     HL,(START)
       LD     (HL),#FF
       INC    HL
       LD     (23627),HL
       LD     (HL),#80
       INC    HL
       LD     (23641),HL	; and clear program and VARS area
       JP     #16B0

; Write BASICODE program to tape in BASICODE format
	   
SVPROG LD     HL,(BCPROG)	; Get pointer to start of program
       LD     A,(HL)
       CP     #82		; Must be valid BASICODE program
       RET    NZ
       JP     SVBLOCK
	   
; Variables used by various routines
	   
LASTLN DEFW   #0000		; Pointer to last line processed
SCR_AD DEFW   #4000		; Pointer to last character printed in display
BCPROG DEFW   #0000		; Pointer to start of raw BASICODE program
LNPTR  DEFW   #0000
LASTNR DEFW   #0000		; Number of last line processed
START  DEFW   #0000
; CHECKS DEFB   #00		; Running value of checksum *** 20160325: Removed
L_LEN  DEFB   #00
ON_CHR DEFB   #00		; Code of last ON command (GOTO/GOSUB)

; Tape messages

F_MSG  DEFB   #80
       DEFM   "PRESS <PLAY>&<REC> THEN ANY KE"
       DEFB   "Y"+#80
       DEFM   "START TAPE."
       DEFB   "."+#80
       DEFM   "LOW BLOCK - IGNORE"
       DEFB   "D"+#80
       DEFM   "HIGH BLOCK - REWIND TAP"
       DEFB   "E"+#80
       DEFM   "LOAD ERROR - REWIND TAP"
       DEFB   "E"+#80

; Start of BASICODE Data channel block in channel table
	   
CH_TAB DEFW   BC_OUT	; Address of output routine
       DEFW   BC_IN		; Address of input routine
       DEFB   "X"		; Device name - "X"
       DEFW   1043,1043	; Dummy addresses
       DEFW   1043		; Length of channel block
       DEFB   #FF		;R/W FLAG
       DEFW   #0000		;POS.
       DEFB   #00		; Record number of this block
       DEFB   #01		; Start of tape buffer
       DEFB   #00		; Record number of block on tape

; Open BASICODE data file for write
; This routine is called by "LET O=NF+4 AND USR WOPEN" at line 500 where NF=1
; So NF+4 is put on the stack and can be fetched using the CALL to #1E94 (FIND_INT1)
	   
WOPEN  CALL   #1E94		; Channel number (usually 5)
       PUSH   AF
       CALL   #2D28		; Re-stack number to balance the stack
       POP    AF
       CP     #10		; Must be 15 or lower
BADSTR JP     NC,#1725
       CALL   #1727		; Find offset in BC
       LD     A,B
       OR     C
       JR     NZ,BADSTR	; Error if already open
       PUSH   HL
       LD     HL,(23635)
       DEC    HL
       LD     BC,1043
       CALL   #1655		; Make room for 1043 bytes in CHANS area
       INC    HL
       PUSH   HL
       POP    IX
       EX     DE,HL
       DEC    HL
       LD     (HL),#83	; Enter ETX char at end of buffer
       LD     HL,CH_TAB
       LD     C,#11
       LDIR		; Set first 17 bytes in channel block
       PUSH   IX
       POP    HL
       LD     DE,(23631)
       AND    A
       SBC    HL,DE
       INC    HL
       EX     DE,HL
       POP    HL
       LD     (HL),E	; Enter offset of new channel in stream table
       INC    HL
       LD     (HL),D
       RET

; Open BASICODE data file for read
	   
ROPEN  CALL   WOPEN		; create channel block
       LD     (IX+11),#00	; signal "read file"
       JP     FETCH_BUFF	; Get first block

; Close BASICODE data file
	   
CLOSE  CALL   #1E94
       PUSH   AF
       CALL   #2D28
       POP    AF
       CP     #10
       JP     NC,#1725
       CALL   #1727
       LD     A,B
       OR     C
       RET    Z
       LD     IX,(23631)
       DEC    BC
       PUSH   BC
       ADD    IX,BC
       LD     A,(IX+4)
       CP     "X"
       JP     NZ,#1725
       BIT    7,(IX+11)
       JR     Z,DEL_CH
       LD     E,(IX+12)
       LD     D,(IX+13)
       PUSH   IX
       ADD    IX,DE
FILBUF LD     (IX+17),#04
       INC    IX
       INC    DE
       BIT    2,D
       JR     Z,FILBUF
       POP    IX
       PUSH   HL
       CALL   OUT_BUF
       POP    HL
DEL_CH LD     (HL),#00
       INC    HL
       LD     (HL),#00
       LD     HL,#5C16
       LD     A,#10
       LD     BC,1043
STR_LP LD     E,(HL)
       INC    HL
       LD     D,(HL)
       EX     (SP),HL
       AND    A
       SBC    HL,DE
       ADD    HL,DE
       EX     (SP),HL
       JR     NC,NXT_CH
       EX     DE,HL
       AND    A
       SBC    HL,BC
       EX     DE,HL
       LD     (HL),D
       DEC    HL
       LD     (HL),E
       INC    HL
NXT_CH INC    HL
       DEC    A
       JR     NZ,STR_LP
       POP    DE
       PUSH   IX
       POP    HL
       JP     #19E8

; Character output routine for BASICODE Cassette channels
	   
BC_OUT LD     IX,(23633)
       BIT    7,(IX+11)
       JR     NZ,NOREAD
       CALL   BASERR
       DEFB   #1F
NOREAD LD     E,(IX+12)
       LD     D,(IX+13)
       PUSH   IX
       ADD    IX,DE
       LD     (IX+17),A
       POP    IX
       INC    DE
       LD     (IX+12),E
       LD     (IX+13),D
       BIT    2,D
       RET    Z
       LD     (IX+13),E
       CALL   OUT_BUF
       INC    (IX+16)
       RET

; Character input routine for BASICODE Cassette channels
	   
BC_IN  LD     IX,(23633)
       BIT    7,(IX+11)
       JR     Z,NO_WRT
       CALL   BASERR
       DEFB   #1E
NO_WRT BIT    2,(IX+13)
       JR     Z,GET_CH
       INC    (IX+14)
       LD     (IX+13),#00
       CALL   FETCH_BUFF
GET_CH LD     E,(IX+12)
       LD     D,(IX+13)
       PUSH   IX
       ADD    IX,DE
       LD     A,(IX+17)
       POP    IX
       CP     #04
       JR     NZ,NO_EOF
       DEC    A
       RET
NO_EOF INC    DE
       LD     (IX+12),E
       LD     (IX+13),D
       CP     #80
       JR     NC,ILLCHR
       CP     #20
       JR     NC,BCIEND
       CP     #0D
       JR     Z,BCIEND
ILLCHR LD     A,"#"
BCIEND SCF
       RET

; Print tape messages at bottom of screen and wait for keypress
	   
WRMSG  PUSH   AF
       XOR    A
       CALL   #1601
       LD     B,#01
       CALL   #0E44
       LD     (IY+49),#02
       LD     BC,#1721
       CALL   #0DD9
       POP    AF
       PUSH   AF
       LD     DE,F_MSG
       CALL   #0C0A
       POP    AF
       LD     (23633),IX
       AND    A
       RET    NZ
       LD     HL,23611
       RES    5,(HL)
WT_KEY BIT    5,(HL)
       JR     Z,WT_KEY
       RES    5,(HL)
       LD     B,#01
       JP     #0E44

; Write channel buffer to tape
	   
OUT_BUF
       XOR    A
       CALL   WRMSG		; "Press <PLAY> & <REC> then any key"
       PUSH   IX
       POP    HL
       LD     DE,15		; Tape buffer starts at offset 15
       ADD    HL,DE

; *** 20160325: Code removed as the checksum is now handled by the SVBLOCK routine below
; Note that the length of the channel block remains 1043 bytes to avoid breaking other code
; Hence, the last byte in the channel block is now unused; the penultimate location holds 83H
;       PUSH   HL
;       LD     BC,1027	; 1024 characters to be written plus block number, start & end marker
;       LD     E,#00	; Initialise checksum
;CHK_LP LD     A,(HL)
;       OR     #80
;       XOR    E		; For each character, set bit 7 and XOR with running checksum
;       LD     E,A
;       INC    HL
;       DEC    BC
;       LD     A,B
;       OR     C
;       JR     NZ,CHK_LP
;       LD     (HL),E	; Enter checksum
;       POP    HL		; Restore start of tape buffer pointer
;
; *** 20160325 REMOVE END 
	   
; This subroutine is called for saving both program and data blocks.
; On entry, HL points to start of block to be saved
; An ETX character with bit 7 inverted (83H) marks the end of the block
; *** 20160325: Code inserted so that this routine also calculates the checksum
; so it's no longer necessary for the calling routines to put the checksum after final ETX char
	   
SVBLOC DI			; Interrupt must be disabled for accurate timing
       LD     DE,6000	; Start with a leader of 5 seconds
       CALL   LEADER
; *** 20160325 START of code added
       LD     D,0		; initialise checksum
; *** 20160325 END of code added
;       DEC    BC		; dummy instruction for delay now redundant
       LD     B,43		; This is (729 - 183)/13 + 1
	   
; The following loop saves each character in turn until an ETX character is found

SA_LOOP
       LD     E,(HL)
       SET    7,E			; Bit 7 is always set
; *** 20160325 START of code added for calculating checksum
       LD     A,D
       XOR    E		; update checksum in D
       LD     D,A
; *** 20160325 END of code added (12 extra T-states)
       AND    A		; clear carry flag (redundant instruction but left for accurate timing)
       CALL   SA_PE2
       SCF		; Marker for SA_BIT loop
       NOP
       DEC    BC		; Delay of 10 T-states
SA_BIT RR     E		; Shift out each bit, LSB first
       LD     B,47		; This is (729 - 131)/13 + 1
       JP     Z,BIT_STOP	; If 0, done with byte
       CALL   SA_PE2	; Record a 0 or 1 as indicated by carry flag
       AND    A		; Next bit to shift in is 0 so loop ends after data bits shifted out
       JP     SA_BIT
BIT_STOP
       CALL   SA_PE2	; Now deal with 2 stop bits (Note: carry flag set)
       DEC    BC
       LD     B,49		; This is (729 - 105)/13 + 1
       CALL   SA_PE2
       LD     A,(HL)
       INC    HL		; Advance pointer

       CP     #83
       JP     Z,SA_END	; If ETX sent, jump to send checksum
       
	   
       LD     A,#7F
       IN     A,(#FE)
       RRA
       LD     B,42		; This is (729 - 194)/13 + 1
       JR     C,SA_LOOP	; Loop back unless BREAK pressed
       JR     SA_RET
	   
; The following loop is identical to the previous one, except that now the checksum is sent
	   
SA_END AND    A
       LD     B,47
       CALL   SA_PE2
;       LD     E,(HL)	; *** 20160325: removed as the checksum is now in D
       SCF	
       NOP
       DEC    BC		; *** 20160325: Dummy added to compensate for removed LD above
CH_BIT RR     D		; *** 20160325: originally: RR E
       LD     B,47
       JP     Z,SA_TRL
       CALL   SA_PE2
       AND    A
       JP     CH_BIT
	   
; Now send a trailer of 1 second and exit to the ROM
	   
SA_TRL LD     DE,1200	; NOTE: This also acts as stopbits for the checksum byte
       CALL   LEADER
SA_RET JP     #053F

; This subroutine sends a leader or trailer tone of "1"s for DE/1200 seconds

LEADER LD     B,44
LEAD_1 SCF		; always send a "1" ie 2400 Hz
       CALL   SA_PE2
       LD     B,48		; Timing constant
       DEC    E
       JR     NZ,LEAD_1
       DEC    B		; Allow for longer path so decrease B
       DEC    D
       JP     P,LEAD_1
       RET

; The following subroutine generates the actual BASICODE signal
; Entry is at SA_PE2 which calls SA_PE1 to generate 1 period of either 1200 or 2400 Hz
; If bit to be sent (in Carry flag) is 1, it generates another period of 2400 Hz
; Note: 0-bit: 1458 T-states "on" + 1458 T-states "off"
;       1-bit: (729 T-states "on" + 729 T-states "off") * 2
; On entry, B holds a timing value dependent on the length of the path taken since the last OUT
; more precisely: B = (729 - <path delay>)/13 + 1
; path delay = total number of T-states taken by all instructions from OUT to OUT
	   
SA_PE2 CALL   SA_PE1	; Generate 1 period of 1200 or 2400 Hz as per C-flag
       RET    NC		; If bit was 0, done (22 T-states since last OUT)
       NOP					; Wait 4 T-states
SA_PE1 LD     A,#01		; Blue border and MIC on (rising edge of signal)
DEL1   DJNZ   DEL1		; Wait time specified in B register (13*(B-1)+8 T-states)
       JP     C,SAOUT1	; if bit is 1, do OUT now (2400 Hz signal)
       LD     B,56
DEL2   DJNZ   DEL2		; else, wait 730 T-states for 1200 Hz signal
SAOUT1 OUT    (#FE),A	; Set border and MIC level
       DEC    BC		; Wait 10 T-states
       NOP
;       LD     A,#0E	; Now BORDER yellow and MIC off (falling edge of signal)
       LD     A,#16		; *** 20160325: Now use bit 4 for signalling to allow recording of sound on emulators
       LD     B,53
DEL3   DJNZ   DEL3		; Wait 684 T-states (total 729 from OUT to OUT)
       JP     C,SAOUT2	; If bit is 1, do OUT now
       LD     B,56
DEL4   DJNZ   DEL4		; Else, wait another 730 T-states
SAOUT2 OUT    (#FE),A	; Perform OUT now
       RET    NC		; Done if bit was zero (also compensate for extra RET NC above)
       LD     B,52		; Else, set timing constant for second pass
       RET					; Done with 1's (22 T-states since OUT)
	   
; Fetch a BASICODE data block from tape into buffer area
	   
FETCH_BUFF
       LD     (IY+89),3	; counter for unsuccessful tries
       LD     A,#01
F_AG_1 CALL   WRMSG		; display message and wait for key
       LD     (IY+STX),#81	; look for BASICODE data block
F_AGAI PUSH   IX
       POP    HL
       LD     DE,15
       ADD    HL,DE
       PUSH   HL
       LD     D,H
       LD     E,L
       INC    DE
       LD     BC,1027
       LD     (HL),#00
       LDIR		; clear buffer area
       POP    HL
       CALL   LDBLOCK
       JR     NC,LDERR
       LD     B,#01
       CALL   #0E44		; clear bottom line of display
       LD     A,(IX+16)
       CP     (IX+14)
       RET    Z		; return if correct block loaded
       LD     A,#02
       JR     C,F_AG_1
       LD     A,#03
       JR     F_AG_1	; else print message and try again
LDERR  DEC    (IY+89)	; decrease error counter
       LD     A,4
       JR     NZ,F_AG_1	; max. 3 tries, then "Tape loading error"
TP_ERR RST    8
       DEFB   #1A
	   
; Load a block of BASICODE bytes from tape
; Entry: HL points to memory buffer start, MEMBOT holds 82H for program or 81H for data block
; Buffer MUST contain 0's, if nonzero bytes encountered an "Out of memory" error is given
	   
LDBLOC DI
       LD     (LASTLN),HL
       LD     DE,#50E0
       LD     (SCR_AD),DE	; Initialise address of last display line
       LD     A,#0F
       OUT    (#FE),A	; Border white and MIC off
       IN     A,(#FE)
       RRA
       AND    #20
       OR     #02
       LD     C,A		; initialise state of EAR bit in C
       CP     A
LD_BRK JR     NZ,LDQUIT
LD_FRS CALL   EDGE1
       JR     NC,LD_BRK
       LD     DE,#0415
LD_WAI DJNZ   LD_WAIT	; Now wait 1 second
       DEC    DE
       LD     A,D
       OR     E
       JR     NZ,LD_WAIT
       CALL   EDGE2		; 2 edges must be found
       JR     NC,LD_BRK
	   
; Now wait for a leader tone of 2400 Hz
	   
LD_LEA LD     B,240
       CALL   EDGE2
       JR     NC,LD_BRK
       LD     A,B
       CP     246
       JR     C,LD_FRST
       INC    D
       JR     NZ,LD_LEAD
	   
; Leader tone found, now wait for first byte (82H for program blocks, 81H for data blocks)
	   
WT_STX CALL   LDSYNC
       LD     A,E
       CP     (IY+STX)	; block type must match
       JR     NZ,LD_FRST
       LD     A,C
       XOR    #03
       LD     C,A		; change border colours to signal 'now loading data'
       LD     A,E
       JR     LD_STORE
	   
; Loop for all subsequent bytes and store them
	   
LD_LOO CALL   LDBYTE	; Load another byte from tape
       JR     C,LD_END	; Carry set if trailer found; no more bytes
       LD     A,(HL)
       AND    A
       JR     NZ,LD_OM	; Out of memory if next location in buffer is nonzero
       LD     A,E
       AND    #7F		; Strip bit 7
LD_STO LD     (HL),A
       INC    HL
       CP     #0D
       JR     NZ,LD_PRT
       LD     (LASTLN),HL	; Set LASTLN 1 past last line read in
LD_PRT CALL   DISP_CH	; Print character on bottom of screen
       JR     LD_LOOP
LD_OM  LD     (IY+0),#03	; Signal "Out of memory error"
       JR     LDQUIT
LD_END INC    D
       DEC    D
       JR     Z,LDQUIT	; Test checksum	   
       AND    A		; If nonzero, signal "Tape loading error" so carry reset
	   
; NOTE: At this point, the checksum byte has been stored but corrupted by the AND 7FH before LD_STO.
; Hence, a LOAD BASICODE program immediately followed by a SAVE would fail to send the correct checksum.
; This has been avoided now by letting the SVBLOCK routine do the calculation of the checksum.
	   
LDQUIT BIT    0,(IY+STX)	; Data block?
       JR     NZ,LDBUFF	; yes
       LD     HL,(LASTLN)
       LD     (HL),#83	; Else, ensure program is properly terminated
LDBUFF CALL   #053F		; Tidyup and test for BREAK
       BIT    7,(IY+0)
       RET    NZ		; Return if no error other than "Tape loading error"
       JP     #0058		; else report

; This loop waits for a zero start bit
	   
LDBR_1 JR     NZ,LDQUIT	; Jump if BREAK pressed
LD_ONE LD     B,190		; else, try to sync on a start bit
       CALL   EDGE1
       JR     NC,LDBR_1	; loop back if no valid pulse found
       LD     A,B
       CP     201
       JR     NC,LD_ONE			; 
LDSYNC LD     B,190
       CALL   EDGE1
       JR     NC,LDBR_1
       LD     A,B
       CP     201
       JR     C,LDSYNC
       CALL   EDGE1
       JR     NC,LDBR_1
       LD     A,B
       CP     211
       JR     C,LDSYNC
       JR     LD_MARKER

; Load one byte into E and update checksum in D
	   
LDBYTE LD     E,0		; Wait for start bit
LDBYT1 DEC    E		; Count number of passes
       RET    Z		; if no start bit in 255 passes, end reached (carry set)
       LD     B,190
       CALL   EDGE2
       JR     NC,LDBR_1
       LD     A,B
       CP     211
       JR     C,LDBYT1
LD_MAR LD     E,#80		; Set marker bit in E (LSB goes first)

; This loop reads in a byte bit by bit

LD_BIT LD     B,190
       CALL   EDGE2
       JR     NC,LDBR_1	; Jump if BREAK pressed or other error
       LD     A,B
       CP     211
       JR     NC,LD_ROT
       LD     B,240
       CALL   EDGE2
       JR     NC,LDBR_1
LD_ROT RR     E
       JR     NC,LD_BIT
       LD     A,D
       XOR    E
       LD     D,A
       RET
	   
; Display character read in from tape on bottom line of screen during loading.
; This routine does not scroll but wraps back to start of bottom line
	   
DISP_C PUSH   HL
       PUSH   DE
       PUSH   BC
       CP     #0D
       JR     NZ,CKCTRL
       LD     A,#20
CKCTRL CP     #20
       JR     NC,BASCALC
       LD     A,"#"
BASCAL LD     H,0
       LD     L,A
       ADD    HL,HL
       ADD    HL,HL
       ADD    HL,HL
       LD     BC,#3C00
       ADD    HL,BC
       LD     DE,(SCR_AD)
       PUSH   DE
       LD     B,8
PR_LIN LD     A,(HL)
       LD     (DE),A
       INC    L
       INC    D
       DJNZ   PR_LINE
       POP    HL
       INC    L
       LD     A,L
       OR     #E0
       LD     L,A
       LD     (SCR_AD),HL
       POP    BC
       POP    DE
       POP    HL
       RET
