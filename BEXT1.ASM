; =============================================================================
; BASICODE-3 v3.1 FOR THE ZX SPECTRUM 48K
; Copyright (C) 1985-2017 by JAN BREDENBEEK, HILVERSUM, THE NETHERLANDS
; RELEASED UNDER GNU v3 PUBLIC LICENSE, 2017

; BEXT - BASICODE COMPATIBILITY EXTENSION
; v2.0 - 30 DECEMBER 1985
; v2.02 - 24 NOVEMBER 1987
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

FUNCS  EQU    58840           ; Start of jump-table of user-defined functions
VAL    EQU    FUNCS+9         ; Offset of VAL entry
SCREEN EQU    FUNCS+12        ; Offset of SCREEN$ entry
VALSUB EQU    FUNCS+21        ; VAL subroutine
VALFRC EQU    FUNCS+24        ; fractions
ERROR  EQU    #0053           ; Spectrum's error handler (no ROM paging)

; Jump table for entry points called from BASIC or other modules

       ORG    59450
       JP     INIT            ; initialisation
       JP     RE_ENT          ; re-entry (called from line 1:2)
       JP     FREEMEM         ; calculate free memory (and garbage collect)
       JP     ONERR           ; ON ERROR GOTO routine
       JP     LN_ADDR         ; Entry point to LN_ADDR
       JP     MAIN_9          ; Entry point to MAIN_9
       JP     OUT_LINE        ; Entry point to OUT_LINE
       JP     O_NUM1          ; Entry point to OUT_NUM1
       JP     FN_D            ; Entry point to FN o() (see below)

; -----------------------------------------------------------------------------       
; This is called by FN o() and FN o$() from BASIC, in expressions called by
; add-ons such as Interface 1 and various 3rd party storage systems. These call
; the original SCANNING subroutine in the Spectrum ROM which cannot handle our
; expression syntax. To avoid this, these expressions should be prepended by
; "FN o()+" or "FN o$()+", e.g. OPEN#FN o()+NF+4;"m";FN o()+1;FN o$()+NF$
; (really awkward syntax but only needed in the standard subroutines!)
; The purpose of these functions is to change the return address to SCANRT
; below (which is our equivalent to S_CONT_2 in the Spectrum ROM).
; -----------------------------------------------------------------------------
       
FN_D$  LD     HL,6            ; Point to result flag on the stack
       ADD    HL,SP
       RES    7,(HL)          ; Signal 'string result'

; -----------------------------------------------------------------------------
; FN o() enters here. Note that the original names were FN d() and FN d$() but
; in 1987 the BASICODE Foundation decided to 'legalise' DEFFN so the name had 
; to be changed to a 'reserved' one!
; This code looks for a return address of $289F in the ROM, which is just after
; the recursive call to SCANNING in the ROM (at $24FB) which evaluates the
; FN's result. If found, this address is replaced with the equivalent address
; in our BASICODE interpreter.
; -----------------------------------------------------------------------------
       
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
       LD     HL,1            ; Set NEWPPC to 1 (NOTE: Probably useless since
       LD     (23618),HL      ; NSPPC has to be set too for BASIC to jump!)
       RET

; The return point; restore CH_ADD and DEFADD and jump to S-CONT-2 to continue
; evaluation, but this time using our evaluator.

SCANRT POP    HL
       LD     (23645),HL
       POP    HL
       LD     (23563),HL
       RST    #20
       JP     CONT2

; ---------
; Variables
; ---------

EXTVEC DEFW   53959           ; Address of routine to call on '*' command
ERRPPC DEFW   #0000           ; 'ON ERROR GOTO' line number
PPC    DEFW   #0000           ; Temporary save area for PPC system variable
SUBPPC DEFB   #00             ; Id. for SUBPPC
STRS   DEFW   #0000           ; Start of string space
STRPTR DEFW   #0000           ; Pointer to first used string space

; ----------------------------------------------------------
; SAVE, LOAD, VERIFY & MERGE
; This code mimics the ROM, except:
; - SAVE etc. does not save the variables of a BASIC program
; - SAVE etc... DATA is not supported
; ----------------------------------------------------------

SAVE_ETC
       POP    BC              ; Drop address of SCAN_LOOP
       CALL   SET_PPC         ; Re-enter our interpreter afterwards
       LD     A,(23668)
       SUB    #E0             ; Reduce T_ADDR - it's now 0 for SAVE, 1 for LOAD
       LD     (23668),A       ; 2 for VERIFY and 3 for MERGE
       CALL   EX_EXP          ; Evaluate the file name
       LD     BC,#0011        ; Assume 17 bytes of workspace needed
       LD     A,(23668)
       AND    A
       JR     Z,SA_SPACE      ; Skip when dealing with SAVE
       LD     C,#22           ; Other commands require room for 2 headers
SA_SPACE                      ; (one set by the command and one from the tape)
       RST    #30             ; Reserve room in WORKSP
       PUSH   DE
       POP    IX              ; Copy address to IX
       LD     B,#0B
       LD     A,#20
SA_SP  LD     (DE),A          ; Fill file name with spaces
       INC    DE
       DJNZ   SA_SP
       LD     (IX+1),#FF      ; Signal 'no file name yet'
       CALL   #2BF1           ; Get string parameters
       LD     HL,#FFF6        ; This is -10
       DEC    BC              ; A null name now goes to $FFFF..
       ADD    HL,BC           ; .. and sets carry, and so will names > 10 chars
       INC    BC              ; Restore original length
       JR     NC,SA_NAME      ; Jump if name is 1 to 10 characters in length
       LD     A,(23668)       ; Test for SAVE command
       AND    A               ; SAVE must have a valid name,
       JP     Z,#0642         ; else report 'Invalid file name'.
       LD     A,B             ; Test for null name
       OR     C
       JR     Z,SA_SCR$       ; Skip with null names
       LD     BC,#000A        ; Else, consider at most 10 characters
SA_NAME
       PUSH   IX              ; Valid name given so copy this to the workspace
       POP    HL              ; area
       INC    HL
       EX     DE,HL
       LDIR
SA_SCR$
       RST    #18             ; Get character after name
       CP     #AA             ; Test for 'SCREEN$' variant
       JR     NZ,SA_CODE      ; Skip unless dealing with SCREEN$
       LD     A,(23668)
       CP     #03             ; 'MERGE name SCREEN$' is nonsense
       JR     Z,SA_ERR
       RST    #20             ; Step past SCREEN$ token
       LD     (IX+#0B),#00    ; Enter length - $1B00 (6912)
       LD     (IX+#0C),#1B
       LD     HL,#4000        ; Start address - $4000 (16384)
       LD     (IX+#0D),L
       LD     (IX+#0E),H
       JR     SA_T3           ; It's file type 3 (CODE)
SA_CODE
       CP     #AF             ; Test for 'CODE [x,[y]]' variant
       JR     NZ,SA_LINE      ; Skip unless dealing with 'CODE'
       LD     A,(23668)
       CP     #03             ; 'MERGE name CODE' is nonsense
       JR     Z,SA_ERR
       RST    #20             ; Step past CODE token
       CALL   #2048           ; End of statement reached?
       JR     NZ,SA_C1        ; No, skip
       LD     A,(23668)
       AND    A               ; SAVE name CODE must have parameters
       JR     Z,SA_ERR
       CALL   #1CE6           ; For LOAD/VERIFY, put a zero on the stack
       JR     SA_C2           ; Jump for second parameter
SA_C1  CALL   EX_1NUM         ; Get first CODE parameter, the start address
       CP     ","             ; Is there a second parameter?
       JR     Z,SA_C3         ; Yes, consider that
       LD     A,(23668)
       AND    A               ; Again, SAVE name CODE must have two parameters
SA_ERR JP     Z,#1C8A         ; else report 'Nonsense in BASIC'
SA_C2  CALL   #1CE6           ; For LOAD/VERIFY, stack a zero for length
       JR     SA_C4           ; Skip next two lines
SA_C3  RST    #20             ; Advance past the ','
       CALL   EX_1NUM         ; Evaluate second parameter
SA_C4  CALL   #1E99           ; Get length (or zero) into BC
       LD     (IX+#0B),C      ; Store this in header locations 11 and 12
       LD     (IX+#0C),B
       CALL   #1E99           ; Get start address (or zero) into BC
       LD     (IX+#0D),C      ; Store this in header locations 13 and 14
       LD     (IX+#0E),B
       LD     H,B             ; Set HL to start address or zero
       LD     L,C
SA_T3  LD     (IX+0),#03      ; Set file type to 3 for 'CODE'
       JR     SA_ALL          ; Now join other paths
SA_LINE
       CP     #CA             ; Check for 'LINE x' variant
       JR     Z,SA_L1         ; Jump with 'LINE'
       CALL   #2048           ; It's neither of above variants so check end of
       JR     NZ,SA_C         ; statement, report 'Nonsense in BASIC' otherwise
       LD     (IX+#0E),#80    ; No start line given so set it to $80xx
       JR     SA_T0           ; Jump forward to consider file type 0
SA_L1  LD     A,(23668)       ; LINE has been specified - this variant is only
       AND    A               ; allowed with SAVE, report 'Nonsense in BASIC'
SA_C   JP     NZ,#1C8A        ; otherwise
       RST    #20
       CALL   EX_1NUM         ; A numeric expression must follow
       CALL   #1E99           ; Get start line number into BC
       LD     (IX+#0D),C      ; Store it in header locations 13 and 14
       LD     (IX+#0E),B
SA_T0  LD     (IX+0),#00      ; Set file type to 0 for 'BASIC program'
       LD     HL,(23627)      ; VARS
       LD     DE,(23635)      ; PROG
       SBC    HL,DE           ; Get program length in HL (carry reset)
       LD     (IX+#0B),L      ; Store it in header locations 11/12 and 15/16
       LD     (IX+#0C),H      ; NOTE: We don't save the variables as they are
       LD     (IX+#0F),L      ; incompatible with the ROM's BASIC - also, we
       LD     (IX+#10),H      ; don't store strings in the VARS area anymore!
       EX     DE,HL           ; HL now points to PROG base

; All the variants have been parsed now and it's time to distinguish SAVE from
; LOAD, VERIFY and MERGE.
; HL points to the start address of the block to be SAVEd or loaded.

SA_ALL LD     A,(23668)
       AND    A               ; Are we dealing with SAVE?
       JP     Z,#0970         ; Yes, let the ROM handle this
       PUSH   HL              ; Save start address
       LD     BC,#0011
       ADD    IX,BC           ; Point to second header buffer
LD_HD  PUSH   IX              ; Save this address
       LD     DE,#0011        ; A header of 17 bytes is to be looked for
       XOR    A               ; Signal 'look for header block'
       SCF                    ; Signal 'load it'
       CALL   #0556           ; Call the ROM's LOAD/VERIFY block routine
       POP    IX              ; Restore buffer's address
       JR     NC,LD_HD        ; Loop back until we got a valid header
       LD     A,#FE           ; Select stream -2 (channel S)
       CALL   #1601
       LD     (IY+82),#03     ; Reset SCR_CT to avoid a 'scroll?' prompt
       LD     C,#80           ; Signal 'no match yet'
       LD     A,(IX+0)        ; Now compare type byte of loaded header
       CP     (IX-#11)        ; to our requested type
       JR     NZ,LD_TYPE      ; Skip if they do not match
       LD     C,#F6           ; Else, signal '10 characters to match'
LD_TYPE
       CP     #04             ; A header type 4 or greater is nonsense,
       JR     NC,LD_HD        ; loop back
       LD     DE,#09C0        ; Address of tape messages block in ROM
       PUSH   BC
       CALL   #0C0A           ; Display the appropriate type message
       POP    BC
       PUSH   IX              ; Copy start address of loaded header to DE
       POP    DE
       LD     HL,#FFF0        ; Start of requested file name is 16 bytes before
       ADD    HL,DE
       LD     B,#0A           ; Match 10 characters
       LD     A,(HL)
       INC    A               ; Skip unless the first byte of the requested
       JR     NZ,LD_NAME      ; name is $FF, this signals a wildcard
       LD     A,C             ; C holds -10 when types match or -128 if they
       ADD    A,B             ; don't - after adding 10 from B it will be >=0
       LD     C,A             ; when types match regardless of the name
LD_NAME
       INC    DE              ; This loop compares the characters of the name
       LD     A,(DE)          ; (case-dependent!)
       CP     (HL)
       INC    HL
       JR     NZ,LD_PR
       INC    C               ; Increment C for each matching character
LD_PR  RST    #10             ; .. and print each character on the screen
       DJNZ   LD_NAME         ; Loop for all 10 characters
       BIT    7,C             ; Bit 7 will be reset now when both type and name
       JR     NZ,LD_HD        ; match - loop back otherwise
       LD     A,#0D           ; Follow the name with carriage return
       RST    #10
       POP    HL              ; Retrieve start address

; Now split LOAD, VERIFY and MERGE commands.

       LD     A,(IX+0)        ; Are we dealing with 'CODE' variant?
       CP     #03
       JR     Z,VERIFY        ; Yes, skip to ROM handler
       LD     A,(23668)
       DEC    A               ; a LOAD command will set the zero flag now
       JR     Z,LD_CTL        ; Jump with LOAD (BASIC program)
       CP     #02             ; Check for MERGE
       JP     Z,ME_CTL        ; Jump with MERGE
VERIFY JP     #07CB           ; Jump to the ROM with VERIFY and CODE variants

; The following branch handles LOADing of BASIC programs. The BASIC program
; may have been created either by our BASICODE extension or the ROM's BASIC.
; In the latter case, the variables and the hidden binary numbers have to be 
; removed for compatibility with our extension. This is achieved by making an
; indirect return via the PROGADAPT subroutine.

LD_CTL PUSH   HL              ; Save base address
       LD     L,(IX+#0B)      ; Fetch 'new' length in HL
       LD     H,(IX+#0C)
       LD     E,(IX-6)        ; And 'old' length in DE
       LD     D,(IX-5)
       SCF
       SBC    HL,DE           ; Find difference between old and new
       JR     C,LD_DATA       ; Jump if new length is less
       LD     DE,#0005        ; Else, add 5 bytes overhead
       ADD    HL,DE
       LD     B,H             ; Move this to BC
       LD     C,L
       CALL   #1F05           ; Call TEST-ROOM which will throw an error if
                              ; memory is insufficient
LD_DATA
       POP    DE              ; Retrieve base address
       LD     HL,(23641)      ; E_LINE
       DEC    HL              ; Step one byte down (the VARS area end marker)
       LD     (23647),IX      ; Save IX in X_PTR so it will be adjusted when
       LD     C,(IX+#0B)      ; the area moves and get new length again in BC
       LD     B,(IX+#0C)
       PUSH   BC
       CALL   #19E5           ; Now reclaim the PROG and VARS area
       POP    BC
       LD     DE,PROGADAPT    ; Make a return via PROGADAPT (see above heading)
       PUSH   DE
       PUSH   HL              ; Save base address in HL and length in BC
       PUSH   BC
       CALL   #1655           ; Now make room for the new program
       LD     IX,(23647)      ; Pick up (adjusted) pointer to header block
       INC    HL              ; Point to start of new space
       LD     C,(IX+#0F)      ; Get length of program in BC
       LD     B,(IX+#10)
       ADD    HL,BC           ; Add this to base which yields new base of VARS
       LD     (23627),HL      ; Store new VARS base
       LD     H,(IX+#0E)      ; High byte of start line - we'll test only the
       BIT    7,H             ; highest bit since we allow lines up to 32767
       JP     #08A1           ; Let the ROM handle the rest

; The following code handles MERGE. As with LOAD, the program to be MERGEd may
; have been created using the ROM's BASIC and so the hidden binary numbers in
; lines have to be removed before merging. Variables are not MERGEd since they
; are not compatible with the way we store them.

ME_CTL LD     C,(IX+#0B)      ; Get total length of program+variables into BC
       LD     B,(IX+#0C)
       PUSH   BC              ; Save this
       INC    BC              ; Allow one extra byte for the end marker
       RST    #30             ; Reserve this space in WORKSP
       LD     (HL),#80        ; Terminate it with an end marker
       EX     DE,HL           ; Second byte of new space to HL
       POP    DE              ; Retrieve length
       PUSH   HL              ; Save pointer to new space
       LD     C,(IX+#0F)      ; Now get length of program only into BC
       LD     B,(IX+#10)
       PUSH   BC              ; Save this
       PUSH   HL              ; Copy pointer to new space to IX
       POP    IX
       SCF                    ; Set carry for 'LOAD' (not verify)
       SBC    A,A             ; Set A to $FF for 'data block'
       CALL   #0802           ; Load the program block into WORKSP
       POP    BC              ; Retrieve program length
       POP    HL              ; and pointer to start of new program
ME_MDV PUSH   HL              ; Save again
       ADD    HL,BC
       DEC    HL              ; Point to last byte of program
       LD     A,(HL)          ; If it's created by our BASICODE extension, the
       INC    A               ; last byte will contain $FF - skip if present
       JR     Z,ME_NOW
       INC    HL              ; Else, append it to the program (Note: this will
       LD     (HL),#FF        ; overwrite either the first byte of its
       POP    HL              ; variables or the $80 byte added earlier, but we
       PUSH   HL              ; don't consider them anyway)
       CALL   PA_CR           ; Remove the program's hidden binary numbers
ME_NOW POP    HL              ; Retrieve start of new program
       LD     DE,(23635)      ; Point DE to start of existing program
ME_LP  LD     A,(HL)          ; Enter a loop to consider all program lines,
       INC    A               ; exit when the $FF end marker has been reached
       RET    Z
       LD     B,(HL)          ; Fetch new program's line number into BC
       INC    HL
       LD     C,(HL)
       DEC    HL
       EX     DE,HL           ; Old program's location to HL, new to DE
       PUSH   DE
       CALL   LN_A_1          ; Find any existing line number's address in HL
       POP    DE
       EX     DE,HL           ; Swap pointers back
       CALL   ME_ENTER        ; Enter new line in program at the right position
       JR     ME_LP           ; Loop back

; This subroutine merges a new program line into the existing program. On entry
; the Z flag is set when its line number conflicts with an existing line. In
; that case, the existing line is deleted first before the new line is entered.

ME_ENTER
       JR     NZ,ME_E1        ; Skip if no line number conflict
       LD     (23647),HL      ; Save pointer to new line temporarily
       EX     DE,HL           ; Swap old and new pointers
       EX     AF,AF'          ; Save flags register
       PUSH   HL              ; HL points to existing line
       INC    HL              ; Step past line number bytes
       INC    HL
       LD     C,(HL)          ; Fetch length into BC
       INC    HL
       LD     B,(HL)
       INC    HL
       ADD    HL,BC           ; Point HL past existing line
       POP    DE              ; Retrieve start of existing line in DE
       CALL   #19E5           ; Reclaim the existing line
       EX     DE,HL           ; DE now points to insertion point
       LD     HL,(23647)      ; Retrieve (possibly updated) pointer to new line
       EX     AF,AF'          ; Swap flags register back
ME_E1  PUSH   DE              ; Save destination in DE
       EX     AF,AF'          ; Save flags register
       INC    HL              ; Step past line number bytes
       INC    HL
       LD     C,(HL)          ; Get line length into BC
       INC    HL
       LD     B,(HL)
       DEC    HL              ; Step back to start of new line
       DEC    HL
       DEC    HL
       INC    BC              ; Add 4 bytes for line number and length
       INC    BC
       INC    BC
       INC    BC
       JP     #0943           ; Continue into ROM's counterpart, just after the
                              ; call to NEXT-ONE ($19B8).

; -----------------------------------------------------------------
; Test for commands requiring 're-entry' from the ROM's interpreter
; Called from STMT_LOOP for each statement.
; -----------------------------------------------------------------

RE_TES CP     #CF             ; Code for CAT
       RET    C               ; Exclude lower codes
       CP     #D5             ; This includes CAT, FORMAT, MOVE, ERASE,
       JR     C,SET_PPC       ; OPEN # and CLOSE #
       CP     #FB             ; Include CLS (because of CLS #)
       RET    NZ              ; Return with 'safe' codes

; -----------------------------------------------------------------------------
; A command which might cause entry to the ROM of an expansion unit such as
; Interface-1 or a disk interface is to be executed. 
; This requires special care as these hardware usually don't know about our
; BASICODE interpreter and jump into the ROM's interpreter entry points, so we
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
; This is where it all starts!
; ==============================

INIT   CALL   PROGADAPT       ; Remove variables and embedded FP from program
       LD     SP,(23613)      ; Reclaim stack space
       POP    HL              ; The old error handler
       LD     HL,MAIN_4       ; .. which will be replaced by our own
       PUSH   HL              
       LD     HL,STMT_RET     ; And push our own STMT_RET back
       PUSH   HL

; -----------------------------------------------------------------------------
; We now have control of the system. However, this doesn't mean that we'll
; always keep it. Many extension ROMs, including Sinclair's Interface 1,
; work by trapping errors from 'extended' BASIC commands which the main
; interpreter sees as invalid (e.g. SAVE *"m" etc that deliberately generates a
; syntax error, which pages in IF1's shadow rom at address 0008). The problem
; is that this shadow ROM, once it has done its job, hooks back into the main
; ROM's interpreter loop, thereby disabling our BASICODE interpreter!
; There are various ways to thwart this; the original version of BASICODE-3
; modified the SBRT subroutine in RAM which is used by IF1's shadow rom to call
; main ROM's subroutines. However, this was a specific solution for IF1 owners
; and did not work (or even worse crashed) with third-party extensions such as
; Wafadrive and other storage systems.
; So I had to resort to more generic solutions:
;
; - The FN O() and FN O$() functions which should precede any expressions used
;   in extended commands ensure that an expression will be evaluated by the
;   BASICODE interpreter and not the ROM's interpreter;
;
; - Extended commands that may cause trouble are redirected to the RANDOMIZE
;   USR 59453 at line 1:2 afterwards which enters the RE_ENTtry point above;
;
; - But when all this doesn't help and we're thrown back into the ROM's main
;   loop, eventually we'll end up in the BASIC editor and the machine waits for
;   a key to be pressed - which takes at least one interrupt. So if we
;   can front-end the keyboard interrupt code with our own, we can modify the
;   return address on the stack and take back control - a nice piece of ROP
;   hacking!
;
; So, we have to set Interrupt Mode 2 and set the I register to a page
; containing an interrupt vector - or rather, 257 bytes containing $FD in
; locations $FE00 to $FF00 inclusive (I know the lower byte is always $FF, but
; just to be on the safe side...). Thus the Z80 will jump to location $FDFD, 
; which contains a jump to our INTSRV routine.
; -----------------------------------------------------------------------------

       LD     A,#FE           ; Vector table starts at $FE00
       LD     I,A             ; Set I register
       IM     2               ; and Interrupt Mode 2
       LD     HL,(23730)      ; Fetch RAMTOP
       PUSH   HL              ; and push it on the stack for later
       LD     HL,100          ; allow for 100 bytes of string space
       JP     CLR_2           ; Now jump to the CLEAR handler to set the stack

; -----------------------------------------------------------------------------
; EDITOR ROUTINES
; Nothing fancy here, just enough code to duplicate the functionality of the
; ROM's editor without giving it a chance to take control of the machine...
; Note that INPUT has its own handler which works on channel #2 so we'll get
; the input prompt on the current PRINT position, where BASICODE programs
; usually expect it.
; -----------------------------------------------------------------------------

EDITOR LD     HL,(23613)
       PUSH   HL
ED_AGAIN
       LD     HL,ED_ERROR
       PUSH   HL
       LD     (23613),SP      ; Set ERR_SP to trap errors for now
ED_LOOP
       CALL   #15D4           ; WAIT-KEY
       PUSH   AF
       LD     D,#00
       LD     E,(IY-1)
       LD     HL,#00C8
       CALL   #03B5           ; BEEPER
       POP    AF
       LD     HL,ED_LOOP
       PUSH   HL
       CP     #18
       JP     NC,#0F81        ; ADD-CHAR
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

; Control codes

ED_TABLE
       DEFB   ED_EDIT-$
       DEFB   ED_LEFT-$
       DEFB   ED_RIGHT-$
       DEFB   ED_DOWN-$
       DEFB   ED_UP-$

; Error handler

ED_ERROR
       BIT    4,(IY+48)       ; K channel?
       JP     Z,#1026         ; Exit if not
       LD     (IY+0),#FF      ; Clear error
       LD     D,#00
       LD     E,(IY-2)
       LD     HL,#1A90
       CALL   #03B5           ; make a noise
       JR     ED_AGAIN

; Copy line to the editing area when EDIT is pressed
; Similar to ROM, except we have to deal with 5-digit line numbers...

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
       INC    HL              ; One extra digit to be skipped
       JP     #0FE7           ; Leave the rest to ROM...

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

; (Re-)list a line

ED_LIST
       CALL   AUTO_LIST
       XOR    A
       JP     #1601

; -----------------------------------------------------------------------------
; MAIN EXECUTION LOOP
; This is the main loop of the BASICODE interpreter
; Mostly similar to the rom with a few exceptions...
; -----------------------------------------------------------------------------

MAIN_EXEC
       LD     (IY+49),#02     ; Set lower screen to 2 lines
       CALL   AUTO_LIST       ; Produce a program listing
MAIN_1 CALL   #16B0           ; Clear workspaces
MAIN_2 XOR    A
       CALL   #1601           ; Select channel 0
       LD     (IY+38),#00     ; Clear X-PTR
       CALL   EDITOR          ; Now wait for a BASIC command or new line

; At this point, the ROM does the syntax check. The BASICODE interpreter does
; not. Of course, it's debatable whether leaving out this unique feature of
; ZX BASIC is justified by the saving of only a hundred or so bytes.
; Since this interpreter will be mainly used to run existing BASICODE programs,
; I chose to leave the syntax check out. For the BASICODE developers that are
; still around (if any), my sincerest apologies...

MAIN_3 LD     HL,(23641)      ; E_LINE
       LD     (23645),HL      ; Reset CH_ADD
       CALL   E_LINE_NO       ; Line number to BC
       JP     C,LN_ERR
       LD     A,B             ; Test line number for zero
       OR     C
       JP     NZ,MAIN_ADD     ; If nonzero, enter new BASIC line
       RST    #18
       CP     #0D             ; Empty line?
       JR     Z,MAIN_EXEC     ; Yes, re-list program

; The following lines call the ROM's interpreter with the 'syntax check' flag.
; This is to allow literal numbers in direct commands to be parsed by the ROM's
; (and possible extension hardware like IF1's) interpreter. It will insert the
; hidden binary number representation where needed so the direct command can be
; parsed successfully at runtime by the extension ROM, without having to use
; awkward workarounds like CAT VAL "1" instead of CAT 1 etc.
; Note that you cannot use variables here because the way they are stored is
; incompatible with the ROM's interpreter.

       RES    7,(IY+1)        ; signal 'syntax check'

; NOTE: 8 bytes could have been saved here by calling the ROM at $1B1E rather
;       than $1B29.

       XOR    A
       LD     (23623),A       ; first statement
       DEC    A
       LD     (23610),A       ; clear any errors
       CALL   #1B29           ; call STMT-L-1 to do 'syntax check'
       LD     HL,(23641)      ; E_LINE
       BIT    7,(IY)          ; An error gives bit 7 reset
       CALL   Z,#11A7         ; call REMOVE-FP to remove the FP numbers again

; NOTE: the hidden binary numbers will be ignored by our expression evaluator.

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
MAIN_4 EI                     ; No freeze when interrupts disabled!
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
       CALL   ERRTRP          ; Check ON ERROR GOTO status
       CALL   #16B0
       RES    5,(IY+55)
       CALL   #0D6E
       SET    5,(IY+2)
       POP    AF
       LD     B,A
       CP     #0A
       JR     C,MAIN_5
       ADD    A,#07
MAIN_5 CALL   #15EF           ; Output error code
       LD     A,#20
       RST    #10             ; followed by a space
       LD     A,B
       LD     DE,#1391        ; Base of ROM's error messages
       CP     #1C             ; 'Extended' error code?
       JR     C,MAIN_P        ; No, skip
       LD     DE,EXTMSG       ; Else, point to extended messages
       SUB    #1C
MAIN_P CALL   #0C0A           ; Now output message
MAIN   XOR    A
       LD     DE,#1536        ; Output comma and space
       CALL   #0C0A
       LD     BC,(#5C45)
       BIT    7,B
       JR     Z,MAIN_L
       LD     BC,#0000
MAIN_L CALL   O_NUM1          ; And line number
       LD     A,#3A
       RST    #10
       LD     C,(IY+13)
       LD     B,#00
       CALL   O_NUM1          ; followed by colon and statement number
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

; Extended error messages

EXTMSG DEFB   #80
       DEFM   "Out of string spac"      ; Report S
       DEFB   "e"+#80
       DEFM   "Illegal direc"           ; Report T
       DEFB   "t"+#80
       DEFM   "Bad user routin"         ; Report U
       DEFB   "e"+#80
       DEFM   "Not input fil"           ; Report V
       DEFB   "e"+#80
       DEFM   "Not output fil"          ; Report W
       DEFB   "e"+#80

; --------------------------------------------------------------------------
; MAIN-ADD - add new line to BASIC program.
; Note: ANY change made to the program will result in deleting ALL variables
; and user-defined (FN) functions!
; Sorry folks, but that's the way BASICODE (and other BASICs) work.
; It's also the reason why there are READ and DATA commands, and if you want
; to store data on cassette or other media you can use the file handling
; subroutines 500 to 580.
; Just be thankful it's not ZX81 BASIC :-)
; --------------------------------------------------------------------------

MAIN_A LD     (#5C49),BC      ; Save line number in E_PPC
       LD     HL,(23730)      ; RAMTOP
       LD     (STRPTR),HL     ; Reset string space
       LD     HL,(STRS)       ; Base of string space
       LD     SP,HL           ; Clear the FOR/GOSUB stack
       DEC    HL
       DEC    HL
       LD     (23613),HL      ; Reset ERR_SP
       LD     DE,(23627)      ; VARS
       LD     HL,(23641)      ; E_LINE
       DEC    HL              ; Leave end marker
       CALL   #19E5           ; Reclaim variables area
       LD     BC,(#5C49)      ; Retrieve line number
       LD     DE,(#5C5D)      ; CH_ADD points after line number digits
       LD     HL,REP_G        ; Pre-load stack with error report G ('No room
       PUSH   HL              ; for line') as error return point
       LD     HL,(#5C61)      ; WORKSP points past end of line
       SCF                    ; Exclude end marker ($80) byte in E_LINE
       SBC    HL,DE           ; Find length in HL
       PUSH   HL              ; Save this
       CALL   LN_ADDR         ; Now find location in program where line is to
       JR     NZ,MAIN_B       ; be inserted; jump if no conflicting line exists
       PUSH   HL              ; Save pointer
       INC    HL              ; Step past line number bytes
       INC    HL
       LD     C,(HL)          ; Fetch length into BC
       INC    HL
       LD     B,(HL)
       INC    HL
       ADD    HL,BC           ; HL now points past end
       POP    DE              ; Retrieve start in DE
       CALL   #19E5           ; Delete existing line from the program
MAIN_B POP    BC              ; Retrieve new line's length in BC
       LD     A,C
       DEC    A               ; An empty line (just line number+CR) will now
       OR     B               ; set the zero flag
       JR     Z,MAIN_C        ; .. which just deletes a single line, so skip
       PUSH   BC              ; Save original length
       INC    BC              ; Add 4 bytes for the line number and length
       INC    BC
       INC    BC
       INC    BC
       DEC    HL              ; Point HL before insertion point
       LD     DE,(#5C53)
       PUSH   DE              ; Save original PROG pointer
       CALL   #1655           ; Make room for new line
       POP    HL              ; Restore original PROG pointer (it may have been
       LD     (#5C53),HL      ; moved when adding a first line).
       POP    BC              ; Get a copy of original length
       PUSH   BC
       INC    DE              ; Point DE to last byte of new space
       LD     HL,(#5C61)      ; Get WORKSP pointer
       DEC    HL              ; The last (CR) byte of the new line in E_LINE
       DEC    HL              ; is two bytes down
       LDDR                   ; Now copy the new line to it's place in PROG
       LD     HL,(#5C49)      ; Fetch line number again
       EX     DE,HL           ; HL now points to last of 4 extra bytes at start
       POP    BC              ; Retrieve length
       LD     (HL),B          ; Enter length - MSB after LSB in memory
       DEC    HL
       LD     (HL),C
       DEC    HL
       LD     (HL),E          ; Enter line number - LSB after MSB in memory
       DEC    HL
       LD     (HL),D
MAIN_C POP    AF              ; Drop address of REP_G
       JP     MAIN_EXEC       ; and loop back to main execution loop

; This subroutine is called after LN_ADDR with DE pointing to the current line
; and HL to the line after.

LN_NO1 EX     DE,HL
       LD     DE,#168F
LN_NO  LD     A,(HL)
       INC    A
       JR     Z,LN_NO1
       LD     D,(HL)
       INC    HL
       LD     E,(HL)
       RET

; AUTO-LIST

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

; LIST and LLIST command handlers

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

; Find address of line number BC in HL

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

; Parse line number of newly entered line
; Carry flag set if number is not acceptable (> 32767)

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

; Output line number

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
O_NUM3 LD     BC,#D8F0        ; '-10000'
       CALL   #192A           ; Print first digit or space
       JP     #1A30           ; Leave the rest to the ROM

; Parse integer and return in BC
; Note: Carry flag set if overflow

INT_TO_BC
       LD     HL,#0000
       LD     B,H
       LD     C,L
       CALL   #2D1B           ; Test for digit
       JR     NC,INT_2
       AND    A
       RET
INT_1  LD     H,B             ; HL <- 10*BC
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
       CALL   #0074           ; Next character
       CALL   #2D1B           ; Test for digit
       JR     NC,INT_1        ; Loop back for next digit
       AND    A
       RET

; -----------------------------------------------------------------------------
; The PROGADAPT routine is called on initialisation to remove the variables and
; embedded floating point numbers from any existing program.
; -----------------------------------------------------------------------------

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
       LD     (HL),#FF        ; insert an end marker $FF after the program
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
       CALL   #19E8           ; remove FP
       LD     A,(HL)
NO_NUM CP     #0D
       INC    HL
       JR     NZ,PA_LP
       POP    DE
       JR     PA_CR

; -----------------------------------------------------------------------------
; The ON ERROR GOTO handler
; Called via the jump table from BASIC:
; LET O = <error line number> AND USR 59459
; -----------------------------------------------------------------------------

ONERR  CALL   #1E99           ; Get integer in BC
       PUSH   BC
       CALL   #2D2B           ; Balance the calculator stack
       POP    HL
       LD     (ERRPPC),HL     ; Enter number in ERRPPC
       LD     BC,#0000        ; Return zero
       RET

; The actual error trapping is done below
; (called from main interpreter loop)

ERRTRP LD     HL,(ERRPPC)     ; Get error line number
       LD     A,H
       OR     L
       RET    Z               ; Return if no error handler
       LD     A,(23610)       ; Error code - 1
       INC    A
       RET    Z               ; Return with 'OK'
       CP     #09
       RET    Z               ; Also with 'STOP statement'
       LD     (IY+0),#FF      ; Else, clear error
       LD     (23618),HL      ; and set NEWPPC
       LD     HL,#0000
       LD     (IY+10),L       ; and NSPPC
       LD     (ERRPPC),HL     ; Clear ERRPPC (to avoid a loop...)
       LD     SP,(23613)      ; ERR-SP
       POP    HL
       LD     HL,MAIN_4       ; Ensure error handler is MAIN_4
       PUSH   HL
       JP     STMT_RET        ; Return, making a jump to NEWPPC

; -----------------------------------------------------------------------------
; END OF PART 1
; Now include part 2...
; -----------------------------------------------------------------------------
       
*F 1:BEXT2
