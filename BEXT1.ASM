; BASICODE-3 v3.1 FOR THE ZX SPECTRUM 48K
; Copyright (C) 1985-2017 by JAN BREDENBEEK, HILVERSUM, THE NETHERLANDS
; RELEASED UNDER GNU v3 PUBLIC LICENSE, 2017

; BEXT - BASICODE COMPATIBILITY EXTENSION
; v2.0 - 30 DECEMBER 1985
; v2.02 - 24 NOVEMBER 1987

; This code is largely based on the ZX Spectrum ROM's BASIC, which is copyrighted by Amstrad.
; However, the Spectrum's ROM has been extensively documented in various disassemblies, starting with
; "The Complete Spectrum ROM Disassembly" by Ian Logan and Frank O'Hara (Melbourne House, 1983).
; This disassembly has been the basis of my Basicode EXTension to create an alternative interpreter
; for running BASICODE programs. Code has been copied and modified for BASICODE compatibility while
; at the same time calls and jumps to the ROM code are used as much as possible to save space.
; This means that the presence of the 48K Spectrum's ROM is essential for proper operation.
; It would of course be very challenging to make the Spectrum ROM's BASIC itself BASICODE compatible
; so we could save a lot of duplicated code in RAM and avoid the dirty tricks necessary to trap the
; notorious attempts by many hardware extensions (including Sinclair's Interface 1) to switch back to
; the original ROM BASIC when using their 'extended' commands. On a standalone (possibly emulated)
; 48K Spectrum this might be a viable option, however it would render a lot of hard- and software
; useless since they depend onto a large degree upon fixed addresses in the Spectrum ROM.
; But in these days of emulators where you can switch ROMs with a few clicks, it might be worth a try...

FUNCS  EQU    58840           ; Start of jump-table of user-defined functions
VAL    EQU    FUNCS+9         ; Offset of VAL entry
SCREEN EQU    FUNCS+12        ; Offset of SCREEN$ entry
VALSUB EQU    FUNCS+21        ; VAL subroutine
VALFRC EQU    FUNCS+24        ; fractions
ERROR  EQU    #0053           ; Spectrum's error handler (no ROM paging)

       ORG    59450
       JP     INIT            ; initialisation
       JP     RE_ENT          ; re-entry (called from line 1:2)
       JP     FREEMEM         ; calculate free memory (and garbage collect)
       JP     ONERR           ; ON ERROR GOTO routine
       JP     LN_ADDR         ; Entry point to LN_ADDR
       JP     MAIN_9          ; Entry point to MAIN_9
       JP     OUT_LINE        ; Entry point to OUT_LINE
       JP     O_NUM1          ; Entry point to OUT_NUM1
       JP     FN_D            ; Entry point to FN o()
       
; This is called by FN o() and FN o$() from BASIC, in expressions called by
; add-ons such as Interface 1 and various 3rd party storage systems. These call
; the original SCANNING subroutine in the Spectrum ROM which cannot handle our
; expression syntax. To avoid this, these expressions should be prepended by
; "FN o()+" or "FN o$()+", e.g. OPEN#FN o()+NF+4;"m";FN o()+1;FN o$()+NF$
; (really awkward syntax but only needed in the standard subroutines!)
; The purpose of these functions is to change the return address to SCANRT
; below (which is our equivalent to S_CONT_2 in the Spectrum ROM).
       
FN_D$  LD     HL,6            ; Point to result flag on the stack
       ADD    HL,SP
       RES    7,(HL)          ; Signal 'string result'
       
; FN o() enters here. Note that the original names were FN d() and FN d$() but
; in 1987 the BASICODE Foundation decided to 'legalise' DEFFN so the name had 
; to be changed to a 'reserved' one!
; This code looks for a return address of $289F in the ROM, which is just after
; the recursive call to SCANNING in the ROM (at $24FB) which evaluates the
; FN's result. If found, this address is replaced with the equivalent address
; in our BASICODE interpreter.
       
FN_D   LD     HL,12           ; Point to return address
       ADD    HL,SP
       LD     BC,0            ; Zero result required for USR
       LD     A,(HL)
       CP     #9F             ; Is low byte $9F?
       RET    NZ              ; Return if not
       INC    HL
       LD     A,(HL)
       CP     #28             ; Is high byte $28?
       RET    NZ              ; Return if not
       LD     DE,SCANRT       ; Else, replace with SCANRT in our expression
       LD     (HL),D          ; evaluator
       DEC    HL
       LD     (HL),E
       LD     HL,1            ; Set NEWPPC to 1
       LD     (23618),HL
       RET

; The return point; restore CH_ADD and DEFADD and jump to S-CONT-2

SCANRT POP    HL
       LD     (23645),HL
       POP    HL
       LD     (23563),HL
       RST    #20
       JP     CONT2

; Variables

EXTVEC DEFW   53959           ; Address of routine to call on '*' command
ERRPPC DEFW   #0000           ; 'ON ERROR GOTO' line number
PPC    DEFW   #0000           ; Temporary save area for PPC system variable
SUBPPC DEFB   #00             ; Id. for SUBPPC
STRS   DEFW   #0000           ; Start of string space
STRPTR DEFW   #0000           ; Pointer to first used string space

; SAVE, LOAD, VERIFY & MERGE
; This code mimics the ROM, except:
; - SAVE etc. does not save the variables of a BASIC program
; - SAVE etc... DATA is not supported

SAVE_ETC
       POP    BC
       CALL   SET_PPC
       LD     A,(23668)
       SUB    #E0
       LD     (23668),A
       CALL   EX_EXP
       LD     BC,#0011
       LD     A,(23668)
       AND    A
       JR     Z,SA_SPACE
       LD     C,#22
SA_SPACE
       RST    #30
       PUSH   DE
       POP    IX
       LD     B,#0B
       LD     A,#20
SA_SP  LD     (DE),A
       INC    DE
       DJNZ   SA_SP
       LD     (IX+1),#FF
       CALL   #2BF1
       LD     HL,#FFF6
       DEC    BC
       ADD    HL,BC
       INC    BC
       JR     NC,SA_NAME
       LD     A,(23668)
       AND    A
       JP     Z,#0642
       LD     A,B
       OR     C
       JR     Z,SA_SCR$
       LD     BC,#000A
SA_NAME
       PUSH   IX
       POP    HL
       INC    HL
       EX     DE,HL
       LDIR
SA_SCR$
       RST    #18
       CP     #AA
       JR     NZ,SA_CODE
       LD     A,(23668)
       CP     #03
       JR     Z,SA_ERR
       RST    #20
       LD     (IX+#0B),#00
       LD     (IX+#0C),#1B
       LD     HL,#4000
       LD     (IX+#0D),L
       LD     (IX+#0E),H
       JR     SA_T3
SA_CODE
       CP     #AF
       JR     NZ,SA_LINE
       LD     A,(23668)
       CP     #03
       JR     Z,SA_ERR
       RST    #20
       CALL   #2048
       JR     NZ,SA_C1
       LD     A,(23668)
       AND    A
       JR     Z,SA_ERR
       CALL   #1CE6
       JR     SA_C2
SA_C1  CALL   EX_1NUM
       CP     ","
       JR     Z,SA_C3
       LD     A,(23668)
       AND    A
SA_ERR JP     Z,#1C8A
SA_C2  CALL   #1CE6
       JR     SA_C4
SA_C3  RST    #20
       CALL   EX_1NUM
SA_C4  CALL   #1E99
       LD     (IX+#0B),C
       LD     (IX+#0C),B
       CALL   #1E99
       LD     (IX+#0D),C
       LD     (IX+#0E),B
       LD     H,B
       LD     L,C
SA_T3  LD     (IX+0),#03
       JR     SA_ALL
SA_LINE
       CP     #CA
       JR     Z,SA_L1
       CALL   #2048
       JR     NZ,SA_C
       LD     (IX+#0E),#80
       JR     SA_T0
SA_L1  LD     A,(23668)
       AND    A
SA_C   JP     NZ,#1C8A
       RST    #20
       CALL   EX_1NUM
       CALL   #1E99
       LD     (IX+#0D),C
       LD     (IX+#0E),B
SA_T0  LD     (IX+0),#00
       LD     HL,(23627)
       LD     DE,(23635)
       SBC    HL,DE
       LD     (IX+#0B),L
       LD     (IX+#0C),H
       LD     (IX+#0F),L
       LD     (IX+#10),H
       EX     DE,HL
SA_ALL LD     A,(23668)
       AND    A
       JP     Z,#0970
       PUSH   HL
       LD     BC,#0011
       ADD    IX,BC
LD_HD  PUSH   IX
       LD     DE,#0011
       XOR    A
       SCF
       CALL   #0556
       POP    IX
       JR     NC,LD_HD
       LD     A,#FE
       CALL   #1601
       LD     (IY+82),#03
       LD     C,#80
       LD     A,(IX+0)
       CP     (IX-#11)
       JR     NZ,LD_TYPE
       LD     C,#F6
LD_TYPE
       CP     #04
       JR     NC,LD_HD
       LD     DE,#09C0
       PUSH   BC
       CALL   #0C0A
       POP    BC
       PUSH   IX
       POP    DE
       LD     HL,#FFF0
       ADD    HL,DE
       LD     B,#0A
       LD     A,(HL)
       INC    A
       JR     NZ,LD_NAME
       LD     A,C
       ADD    A,B
       LD     C,A
LD_NAME
       INC    DE
       LD     A,(DE)
       CP     (HL)
       INC    HL
       JR     NZ,LD_PR
       INC    C
LD_PR  RST    #10
       DJNZ   LD_NAME
       BIT    7,C
       JR     NZ,LD_HD
       LD     A,#0D
       RST    #10
       POP    HL
       LD     A,(IX+0)
       CP     #03
       JR     Z,VERIFY
       LD     A,(23668)
       DEC    A
       JR     Z,LD_CTL
       CP     #02
       JP     Z,ME_CTL
VERIFY JP     #07CB
LD_CTL PUSH   HL
       LD     L,(IX+#0B)
       LD     H,(IX+#0C)
       LD     E,(IX-6)
       LD     D,(IX-5)
       SCF
       SBC    HL,DE
       JR     C,LD_DATA
       LD     DE,#0005
       ADD    HL,DE
       LD     B,H
       LD     C,L
       CALL   #1F05
LD_DATA
       POP    DE
       LD     HL,(23641)
       DEC    HL
       LD     (23647),IX
       LD     C,(IX+#0B)
       LD     B,(IX+#0C)
       PUSH   BC
       CALL   #19E5
       POP    BC
       LD     DE,PROGADAPT
       PUSH   DE
       PUSH   HL
       PUSH   BC
       CALL   #1655
       LD     IX,(23647)
       INC    HL
       LD     C,(IX+#0F)
       LD     B,(IX+#10)
       ADD    HL,BC
       LD     (23627),HL
       LD     H,(IX+#0E)
       BIT    7,H
       JP     #08A1

ME_CTL LD     C,(IX+#0B)
       LD     B,(IX+#0C)
       PUSH   BC
       INC    BC
       RST    #30
       LD     (HL),#80
       EX     DE,HL
       POP    DE
       PUSH   HL
       LD     C,(IX+#0F)
       LD     B,(IX+#10)
       PUSH   BC
       PUSH   HL
       POP    IX
       SCF
       SBC    A,A
       CALL   #0802
       POP    BC
       POP    HL
ME_MDV PUSH   HL
       ADD    HL,BC
       DEC    HL
       LD     A,(HL)
       INC    A
       JR     Z,ME_NOW
       INC    HL
       LD     (HL),#FF
       POP    HL
       PUSH   HL
       CALL   PA_CR
ME_NOW POP    HL
       LD     DE,(23635)
ME_LP  LD     A,(HL)
       INC    A
       RET    Z
       LD     B,(HL)
       INC    HL
       LD     C,(HL)
       DEC    HL
       EX     DE,HL
       PUSH   DE
       CALL   LN_A_1
       POP    DE
       EX     DE,HL
       CALL   ME_ENTER
       JR     ME_LP

ME_ENTER
       JR     NZ,ME_E1
       LD     (23647),HL
       EX     DE,HL
       EX     AF,AF'
       PUSH   HL
       INC    HL
       INC    HL
       LD     C,(HL)
       INC    HL
       LD     B,(HL)
       INC    HL
       ADD    HL,BC
       POP    DE
       CALL   #19E5
       EX     DE,HL
       LD     HL,(23647)
       EX     AF,AF'
ME_E1  PUSH   DE
       EX     AF,AF'
       INC    HL
       INC    HL
       LD     C,(HL)
       INC    HL
       LD     B,(HL)
       DEC    HL
       DEC    HL
       DEC    HL
       INC    BC
       INC    BC
       INC    BC
       INC    BC
       JP     #0943

; Test for commands requiring 're-entry' from the ROM's interpreter

RE_TES CP     #CF             ; Code for CAT
       RET    C               ; Exclude lower codes
       CP     #D5             ; This includes CAT, FORMAT, MOVE, ERASE,
       JR     C,SET_PPC       ; OPEN # and CLOSE #
       CP     #FB             ; Include CLS
       RET    NZ

; -----------------------------------------------------------------------------
; A command from an expansion unit such as Interface-1 or a disk interface is
; to be executed. This requires special care as these hardware usually don't
; know about BASICODE and hook into the ROM's interpreter entry points. So we
; would end up with the old Spectrum's BASIC after execution of these commands.
; To force a re-entry of the BASICODE interpreter, we'll set NEWPPC and NSPPC
; to line 1 and statement 2. Line 1 reads 'REM: RANDOMIZE USR VAL "59453" which
; jumps to the RE_ENT code below which re-activates our interpreter.
; -----------------------------------------------------------------------------

SET_PPC
       LD     HL,(23613)      ; ERR_SP
       LD     (HL),#03        ; Restore the ROM's error handler
       INC    HL              ; (if any error occurs, the interrupt service
       LD     (HL),#13        ; code will deal with re-entry)
       LD     HL,(23621)      ; PPC
       PUSH   AF              ; Save A
       LD     A,(23623)       ; Get SUBPPC
       INC    A               ; The program is to be continued at next stmt
       LD     (PPC),HL        ; Save PPC
       LD     (SUBPPC),A      ; .. and SUBPPC
       POP    AF              ; Restore A
       LD     HL,#0001        ; The return point is to be line 1 statement 2
       LD     D,#02
       JP     #1E73           ; Exit to GO TO to set NEWPPC and NSPPC

; The re-entry point from the RANDOMIZE USR 59453 at line 1:2

RE_ENT LD     HL,(23613)      
       LD     DE,MAIN_4       ; Reset error handler to our MAIN_4
       LD     (HL),E
       INC    HL
       LD     (HL),D
       DEC    HL
       LD     DE,STMT_RET     ; and return address to our STMT_RET
       DEC    HL
       LD     (HL),D
       DEC    HL
       LD     (HL),E
       LD     HL,(PPC)
       LD     A,(SUBPPC)
       LD     (23618),HL      ; Set NEWPPC and NSPPC to line and statement
       LD     (23620),A       ; where program is to be continued
       LD     BC,(23670)      ; SEED will be preserved by the RANDOMIZE
       RET

; ==============================
; The initialisation entry point
; ==============================

INIT   CALL   PROGADAPT
       LD     SP,(23613)
       POP    HL
       LD     HL,MAIN_4
       PUSH   HL
       LD     HL,STMT_RET
       PUSH   HL
       LD     A,#FE
       LD     I,A
       IM     2
       LD     HL,(23730)
       PUSH   HL
       LD     HL,100
       JP     CLR_2

;EDITOR ROUTINES
EDITOR LD     HL,(23613)
       PUSH   HL
ED_AGAIN
       LD     HL,ED_ERROR
       PUSH   HL
       LD     (23613),SP
ED_LOOP
       CALL   #15D4
       PUSH   AF
       LD     D,#00
       LD     E,(IY-1)
       LD     HL,#00C8
       CALL   #03B5
       POP    AF
       LD     HL,ED_LOOP
       PUSH   HL
       CP     #18
       JP     NC,#0F81
       CP     #07
       JP     C,#0F81
       CP     #10
       JP     NC,#0F58
       CP     #0C
       JP     NC,#0F92
       LD     E,A
       LD     D,#00
       LD     HL,ED_TABLE-7
       ADD    HL,DE
       LD     E,(HL)
       ADD    HL,DE
       PUSH   HL
       LD     HL,(23643)
       RET

ED_TABLE
       DEFB   ED_EDIT-$
       DEFB   ED_LEFT-$
       DEFB   ED_RIGHT-$
       DEFB   ED_DOWN-$
       DEFB   ED_UP-$
ED_ERROR
       BIT    4,(IY+48)
       JP     Z,#1026
       LD     (IY+0),#FF
       LD     D,#00
       LD     E,(IY-2)
       LD     HL,#1A90
       CALL   #03B5
       JR     ED_AGAIN

ED_EDIT
       LD     BC,(23625)
       CALL   LN_ADDR
       CALL   LN_NO
       LD     A,D
       OR     E
       JP     Z,#1097
       LD     (23625),DE
       PUSH   HL
       INC    HL
       LD     C,(HL)
       INC    HL
       LD     B,(HL)
       LD     HL,#000A
       ADD    HL,BC
       LD     B,H
       LD     C,L
       CALL   #1F05
       CALL   #1097
       LD     HL,(23633)
       EX     (SP),HL
       PUSH   HL
       LD     A,#FF
       CALL   #1601
       POP    HL
       DEC    HL
       DEC    (IY+15)
       CALL   OUT_LINE
       INC    (IY+15)
       LD     HL,(23641)
       INC    HL
       JP     #0FE7

ED_DOWN
       LD     HL,23625
       CALL   LN_FETCH
       JR     ED_LIST

ED_LEFT
       JP     #1007

ED_RIGHT
       JP     #100C

ED_UP  LD     BC,(23625)
       CALL   LN_ADDR
       EX     DE,HL
       CALL   LN_NO
       LD     HL,#5C4A
       CALL   #191C
ED_LIST
       CALL   AUTO_LIST
       XOR    A
       JP     #1601


;MAIN EXECUTION LOOP

MAIN_EXEC
       LD     (IY+49),#02
       CALL   AUTO_LIST
MAIN_1 CALL   #16B0
MAIN_2 XOR    A
       CALL   #1601
       LD     (IY+38),#00
       CALL   EDITOR
MAIN_3 LD     HL,(23641)
       LD     (23645),HL
       CALL   E_LINE_NO
       JP     C,LN_ERR
       LD     A,B
       OR     C
       JP     NZ,MAIN_ADD
       RST    #18
       CP     #0D
       JR     Z,MAIN_EXEC
       RES    7,(IY+1)
       XOR    A
       LD     (23623),A
       DEC    A
       LD     (23610),A
       CALL   #1B29
       LD     HL,(23641)
       BIT    7,(IY)
       CALL   Z,#11A7
       BIT    0,(IY+48)
       CALL   NZ,#0DAF
       CALL   #0D6E
       LD     A,#19
       SUB    (IY+79)
       LD     (23692),A
       SET    7,(IY+1)
       LD     (IY+0),#FF
       LD     (IY+10),#01
       CALL   PROG_RUN
MAIN_4 EI
       HALT
       RES    5,(IY+1)
       BIT    1,(IY+48)
       CALL   NZ,#0ECD
       LD     A,(23610)
       INC    A
MAIN_G PUSH   AF
       LD     HL,#0000
       LD     (IY+55),H
       LD     (IY+38),H
       LD     (23563),HL
       INC    L
       LD     (23574),HL
       CALL   ERRTRP
       CALL   #16B0
       RES    5,(IY+55)
       CALL   #0D6E
       SET    5,(IY+2)
       POP    AF
       LD     B,A
       CP     #0A
       JR     C,MAIN_5
       ADD    A,#07
MAIN_5 CALL   #15EF
       LD     A,#20
       RST    #10
       LD     A,B
       LD     DE,#1391
       CP     #1C
       JR     C,MAIN_P
       LD     DE,EXTMSG
       SUB    #1C
MAIN_P CALL   #0C0A
MAIN   XOR    A
       LD     DE,#1536
       CALL   #0C0A
       LD     BC,(#5C45)
       BIT    7,B
       JR     Z,MAIN_L
       LD     BC,#0000
MAIN_L CALL   O_NUM1
       LD     A,#3A
       RST    #10
       LD     C,(IY+13)
       LD     B,#00
       CALL   O_NUM1
       CALL   #1097
       LD     A,(#5C3A)
       INC    A
       JR     Z,MAIN_9
       CP     #09
       JR     Z,MAIN_6
       CP     #15
       JR     NZ,MAIN_7
MAIN_6 INC    (IY+13)
MAIN_7 LD     BC,#0003
       LD     DE,#5C70
       LD     HL,#5C44
       BIT    7,(IY+10)
       JR     Z,MAIN_8
       ADD    HL,BC
MAIN_8 LDDR
       LD     HL,(23621)
       BIT    7,H
       JR     NZ,MAIN_9
       LD     (23625),HL
MAIN_9 LD     (IY+10),#FF
       RES    3,(IY+1)
       JP     MAIN_2
LN_ERR LD     A,#0C
       JR     CLRPPC
REP_G  LD     A,#10
CLRPPC LD     BC,#0000
       LD     (#5C45),BC
       LD     (IY+13),#01
       JP     MAIN_G
EXTMSG DEFB   #80,"O","u"
       DEFB   "t"," ","o"
       DEFB   "f"," ","s"
       DEFB   "t","r","i"
       DEFB   "n","g"," "
       DEFB   "s","p","a"
       DEFB   "c",#E5,"I"
       DEFB   "l","l","e"
       DEFB   "g","a","l"
       DEFB   " ","d","i"
       DEFB   "r","e","c"
       DEFB   #F4
       DEFM   "Bad user routin"
       DEFB   "e"+#80
       DEFM   "Not input fil"
       DEFB   "e"+#80
       DEFM   "Not output fil"
       DEFB   "e"+#80
MAIN_A LD     (#5C49),BC
       LD     HL,(23730)
       LD     (STRPTR),HL
       LD     HL,(STRS)
       LD     SP,HL
       DEC    HL
       DEC    HL
       LD     (23613),HL
       LD     DE,(23627)
       LD     HL,(23641)
       DEC    HL
       CALL   #19E5
       LD     BC,(#5C49)
       LD     DE,(#5C5D)
       LD     HL,REP_G
       PUSH   HL
       LD     HL,(#5C61)
       SCF
       SBC    HL,DE
       PUSH   HL
       CALL   LN_ADDR
       JR     NZ,MAIN_B
       PUSH   HL
       INC    HL
       INC    HL
       LD     C,(HL)
       INC    HL
       LD     B,(HL)
       INC    HL
       ADD    HL,BC
       POP    DE
       CALL   #19E5
MAIN_B POP    BC
       LD     A,C
       DEC    A
       OR     B
       JR     Z,MAIN_C
       PUSH   BC
       INC    BC
       INC    BC
       INC    BC
       INC    BC
       DEC    HL
       LD     DE,(#5C53)
       PUSH   DE
       CALL   #1655
       POP    HL
       LD     (#5C53),HL
       POP    BC
       PUSH   BC
       INC    DE
       LD     HL,(#5C61)
       DEC    HL
       DEC    HL
       LDDR
       LD     HL,(#5C49)
       EX     DE,HL
       POP    BC
       LD     (HL),B
       DEC    HL
       LD     (HL),C
       DEC    HL
       LD     (HL),E
       DEC    HL
       LD     (HL),D
MAIN_C POP    AF
       JP     MAIN_EXEC
LN_NO1 EX     DE,HL
       LD     DE,#168F
LN_NO  LD     A,(HL)
       INC    A
       JR     Z,LN_NO1
       LD     D,(HL)
       INC    HL
       LD     E,(HL)
       RET
AUTO_L LD     (#5C3F),SP
       LD     (IY+2),#10
       CALL   #0DAF
       SET    0,(IY+2)
       LD     B,(IY+49)
       CALL   #0E44
       RES    0,(IY+2)
       SET    0,(IY+48)
       LD     HL,(#5C49)
       LD     DE,(#5C6C)
       AND    A
       SBC    HL,DE
       ADD    HL,DE
       JR     C,A_L_2
       PUSH   DE
       LD     B,H
       LD     C,L
       CALL   LN_ADDR
       LD     DE,#02C0
       EX     DE,HL
       SBC    HL,DE
       EX     (SP),HL
       LD     B,H
       LD     C,L
       CALL   LN_ADDR
       POP    BC
A_L_1  PUSH   BC
       PUSH   HL
       INC    HL
       INC    HL
       LD     C,(HL)
       INC    HL
       LD     B,(HL)
       INC    HL
       ADD    HL,BC
       EX     DE,HL
       POP    HL
       POP    BC
       ADD    HL,BC
       JR     C,A_L_3
       EX     DE,HL
       LD     D,(HL)
       INC    HL
       LD     E,(HL)
       DEC    HL
       LD     (#5C6C),DE
       JR     A_L_1
A_L_2  LD     (#5C6C),HL
A_L_3  LD     HL,(#5C6C)
       LD     B,H
       LD     C,L
       CALL   LN_ADDR
       JR     Z,A_L_4
       EX     DE,HL
A_L_4  CALL   LIST_ALL
       RES    4,(IY+2)
       RET
LLIST  LD     A,#03
       JR     LIST_1
LIST   LD     A,#02
LIST_1 LD     (IY+2),#00
       CALL   #1601
       RST    #18
       CALL   STR_ALT
       JR     C,LIST_4
       RST    #18
       CP     #3B
       JR     Z,LIST_2
       CP     #2C
       JR     NZ,LIST_3
LIST_2 RST    #20
       CALL   EX_1NUM
       JR     LIST_5
LIST_3 CALL   USE_ZERO
       JR     LIST_5
LIST_4 CALL   FETCH_NUM
LIST_5 CALL   #1E99
       LD     (#5C49),BC
       CALL   LN_ADDR
       LD     E,#01
LIST_ALL
       CALL   OUT_LINE
       RST    #10
       CALL   #1F54
       JP     NC,#0D00
       BIT    4,(IY+2)
       JR     Z,LIST_ALL
       LD     A,(#5C6B)
       SUB    (IY+79)
       JR     NZ,LIST_ALL
       XOR    E
       RET    Z
       PUSH   HL
       PUSH   DE
       LD     HL,#5C6C
       CALL   LN_FETCH
       POP    DE
       POP    HL
       JR     LIST_ALL
       
; OUT_LINE routine, but this one can handle line numbers > 9999...       
       
OUT_LINE
       LD     BC,(#5C49)
       CALL   #1980
       LD     D,#3E
       JR     Z,O_L_1
       LD     DE,#0000
       RL     E
O_L_1  LD     (IY+45),E
       LD     A,(HL)
       POP    BC
       INC    A
       RET    Z
       PUSH   BC
       CALL   O_NUM2
       JP     #1871
LN_FETCH
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       PUSH   HL
       LD     B,D
       LD     C,E
       INC    BC
       CALL   LN_ADDR
       CALL   LN_NO
       POP    HL
       JP     #191C
LN_ADDR
       LD     HL,(#5C53)
LN_A_1 LD     D,H
       LD     E,L
LN_A_2 LD     A,(HL)
       CP     B
       JR     NC,LN_A_3
LN_NXT PUSH   HL
       INC    HL
       INC    HL
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       INC    HL
       ADD    HL,DE
       POP    DE
       JR     LN_A_2
LN_A_3 RET    NZ
       INC    HL
       LD     A,(HL)
       DEC    HL
       CP     C
       JR     C,LN_NXT
       RET
E_LINE_NO
       LD     HL,(#5C59)
       DEC    HL
       LD     (#5C5D),HL
       RST    #20
       CALL   INT_TO_BC
       RET    C
       LD     A,B
       RLA
       RET
O_NUM1 PUSH   DE
       PUSH   HL
       XOR    A
       LD     H,B
       LD     L,C
       LD     E,#FF
       JR     O_NUM3
O_NUM2 PUSH   DE
       LD     D,(HL)
       INC    HL
       LD     E,(HL)
       PUSH   HL
       EX     DE,HL
       LD     E,#20
O_NUM3 LD     BC,#D8F0
       CALL   #192A
       JP     #1A30
INT_TO_BC
       LD     HL,#0000
       LD     B,H
       LD     C,L
       CALL   #2D1B
       JR     NC,INT_2
       AND    A
       RET
INT_1  LD     H,B
       LD     L,C
       ADD    HL,HL
       RET    C
       ADD    HL,HL
       RET    C
       ADD    HL,BC
       RET    C
       ADD    HL,HL
       RET    C
INT_2  LD     D,#00
       SUB    #30
       LD     E,A
       ADD    HL,DE
       RET    C
       LD     B,H
       LD     C,L
       CALL   #0074
       CALL   #2D1B
       JR     NC,INT_1
       AND    A
       RET
PROGADAPT
       LD     HL,(#5C4B)
       DEC    HL
       LD     A,(HL)
       INC    A
       RET    Z
       INC    HL
       EX     DE,HL
       LD     HL,(#5C59)
       DEC    HL
       CALL   #19E5
       DEC    HL
       LD     DE,(#5C53)
       PUSH   DE
       CALL   #1652
       INC    HL
       INC    HL
       LD     (HL),#FF
       POP    HL
       LD     (#5C53),HL
PA_CR  LD     A,(HL)
       INC    A
       RET    Z
       INC    HL
       INC    HL
       PUSH   HL
       INC    HL
       INC    HL
PA_LP  LD     A,(HL)
       CP     #0E
       JR     NZ,NO_NUM
       LD     BC,#0006
       EX     (SP),HL
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       EX     DE,HL
       SBC    HL,BC
       EX     DE,HL
       LD     (HL),D
       DEC    HL
       LD     (HL),E
       EX     (SP),HL
       CALL   #19E8
       LD     A,(HL)
NO_NUM CP     #0D
       INC    HL
       JR     NZ,PA_LP
       POP    DE
       JR     PA_CR

ONERR  CALL   #1E99
       PUSH   BC
       CALL   #2D2B
       POP    HL
       LD     (ERRPPC),HL
       LD     BC,#0000
       RET

ERRTRP LD     HL,(ERRPPC)
       LD     A,H
       OR     L
       RET    Z
       LD     A,(23610)
       INC    A
       RET    Z
       CP     #09
       RET    Z
       LD     (IY+0),#FF
       LD     (23618),HL
       LD     HL,#0000
       LD     (IY+10),L
       LD     (ERRPPC),HL
       LD     SP,(23613)
       POP    HL
       LD     HL,MAIN_4
       PUSH   HL
       JP     STMT_RET

; Now include part 2...       
       
*F 1:BEXT2
