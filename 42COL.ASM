; BASICODE-3 v3.1 FOR THE ZX SPECTRUM 48K
; Copyright (C) 1985-2017 by JAN BREDENBEEK, HILVERSUM, THE NETHERLANDS
; RELEASED UNDER GNU v3 PUBLIC LICENSE, 2017

; 42-COLUMN SCREEN DRIVER VERSION 1.6
; Last revision: 24 november 1987

CHARS  EQU    58072           ; character set (needs to be 8-byte aligned!)

       ORG    56790
       JP     INIT            ; initialisation
       JP     SUB200          ; get a key currently depressed
       JP     PAUSE           ; wait for a key
       JP     PRTSTR          ; plot a string in the graphics coordinate system
       
S_POSN DEFW   #182B           ; 24-row number, 43-line number of cursor position
DF_CC  DEFW   #4000           ; address in display file
DF_SZ  DEFB   #00             ; number of lines in lower display window
SCFLAG DEFB   #FF             ; 'scroll?' prompt flag
TEMP_P DEFB   #00
BL_CT  DEFB   #00             ; counter for blinking cursor
       DEFM   "(C) 1984 J. Bredenbeek 1.6" ; a short message from the author

; Initialise the driver. This creates an extra 'S' channel in the CHANS area
; and makes #2 point to it.
       
INIT   LD     HL,(23635)
       DEC    HL
       LD     BC,11           ; make room for 11 bytes before PROG
       CALL   #1655
       LD     HL,TB_END
       LD     C,11
       LDDR                   ; and initialise the channel block
       LD     HL,(23631)
       EX     DE,HL
       INC    HL
       AND    A
       SBC    HL,DE
       INC    HL              ; form offset from CHANS +1 in HL
       LD     (23578),HL      ; and enter it into channel pointer for #2
       LD     A,#03
       CALL   #1601           ; select #3 (printer channel)
       LD     HL,(23633)
       LD     E,(HL)
       INC    HL
       LD     D,(HL)
       EX     DE,HL
       LD     BC,#09F4        ; address of standard output routine
       AND    A
       SBC    HL,BC           ; do we have a custom printer driver?
       JR     NZ,I_END        ; yes, leave it alone
       LD     HL,OUTCHR       ; but if using standard ZX printer, change the
       EX     DE,HL           ; driver's address to ours so it will print
       LD     (HL),D          ; in 42 columns too
       DEC    HL
       LD     (HL),E
I_END  LD     A,#02           ; re-select channel #2
       JP     #1601

       DEFW   OUTCHR          ; our output routine
       DEFW   GETKEY          ; our input routine
       DEFB   "S"             ; 'S'
       DEFW   11              ; output routine for shadow rom (dummy)
       DEFW   11              ; input routine for shadow rom (dummy)
       DEFW   11              ; length of channel definition block
TB_END EQU    $-1

; The output routine enters here
; The A register holds the character to be printed

OUTCHR PUSH   AF
       LD     A,(23689)
       CP     24
       JR     NZ,TST_PR
       BIT    1,(IY+1)
       JR     NZ,TST_PR
       LD     BC,#1721
       CALL   #0DD9
       LD     BC,#182B
       CALL   CL_SET
TST_PR BIT    1,(IY+48)
       JR     NZ,NO_SET
       LD     (IY+69),43
NO_SET POP    AF
       CALL   L0B03
       CP     #7F
       JR     Z,DELETE
       CP     #06
       JR     Z,COMMA
       CP     #20
       JP     NC,L0AD9
       CP     #0D
       JP     C,L0A69
       LD     HL,C1-#0D
       LD     E,A
       LD     D,#00
       ADD    HL,DE
L0A0B  LD     E,(HL)
       ADD    HL,DE
       PUSH   HL
       JP     L0B03
C1     DEFB   ENTER-$
       DEFB   L0A69-$
       DEFB   L0A69-$
       DEFB   L0A7A-$
       DEFB   L0A7A-$
       DEFB   L0A7A-$
       DEFB   L0A7A-$
       DEFB   L0A7A-$
       DEFB   L0A7A-$
       DEFB   L0A75-$
       DEFB   L0A75-$
       DEFB   L0A7A-$
       DEFB   COMMA-$
       DEFB   SC_OFF-$
       DEFB   SC_ON-$
       DEFB   P_BACK-$
       DEFB   P_RGHT-$
       DEFB   P_DOWN-$
       DEFB   P_UP-$
DELETE CALL   P_BACK
       LD     A,#20
       CALL   L0B65
P_BACK INC    C
       LD     A,44
       CP     C
       JR     NZ,L0A3A
       BIT    1,(IY+1)
       JR     NZ,L0A38
       INC    B
       LD     C,#02
       LD     A,#19
       CP     B
       JR     NZ,L0A3A
       DEC    B
L0A38  LD     C,#2B
L0A3A  JP     CL_SET
P_RGHT LD     A,(#5C91)
       PUSH   AF
       LD     (IY+87),#01
       LD     A,#20
       CALL   L0B65
       POP    AF
       LD     (#5C91),A
       JP     L0ADC
P_DOWN DEC    B
       LD     A,(DF_SZ)
       CP     B
       RET    NC
       JR     E_SET

P_UP   LD     A,B
       CP     24
       RET    Z
       INC    B
       JR     E_SET
ENTER  BIT    1,(IY+1)
       JP     NZ,#0ECD
       LD     C,43
       CALL   SCROLL
       DEC    B
E_SET  JP     CL_SET
COMMA  LD     A,C
       CP     23
       LD     A,21
       JR     NC,L0AC3
       XOR    A
       JR     L0AC3
L0A69  LD     A,#3F
       JP     L0AD9
SC_OFF XOR    A
       LD     (SCFLAG),A
       RET
SC_ON  LD     A,#FF
       LD     (SCFLAG),A
       RET
L0A6D  LD     DE,L0A87
       LD     (#5C0F),A
       JR     L0A80
L0A75  LD     DE,L0A6D
       JR     L0A7D
L0A7A  LD     DE,L0A87
L0A7D  LD     (#5C0E),A
L0A80  LD     HL,(#5C51)
       LD     (HL),E
       INC    HL
       LD     (HL),D
       RET
L0A87  LD     DE,OUTCHR
       CALL   L0A80
       LD     HL,(#5C0E)
       LD     D,A
       LD     A,L
       CP     24
       JR     NZ,CONT
       INC    D
       DEC    D
       JP     Z,#1E9F
       SUB    D
       JR     C,L0AAC
       LD     (DF_SZ),A
       LD     BC,#182B
       JP     CL_SET
CONT   CP     #16
       JP     C,#2211
       JR     NZ,L0AC2
       LD     B,H
       LD     C,D
       LD     A,41
       SUB    C
       JR     C,L0AAC
       ADD    A,#02
       LD     C,A
       BIT    1,(IY+1)
       JR     NZ,L0ABF
       LD     A,#17
       SUB    B
L0AAC  JP     C,#1E9F
       INC    A
       LD     B,A
       LD     A,(DF_SZ)
       CP     B
       JP     NC,#0C86
L0ABF  JP     CL_SET
L0AC2  LD     A,H
L0AC3  CALL   L0B03
       ADD    A,C
       DEC    A
TABSUB SUB    42
       JR     NC,TABSUB
       ADD    A,42
       RET    Z
       LD     D,A
L0AD0  LD     A,#20
       CALL   #0C3B
       DEC    D
       JR     NZ,L0AD0
       RET
L0AD9  CALL   L0B24
L0ADC  BIT    1,(IY+1)
       JP     NZ,#0AFC
       LD     (S_POSN),BC
       LD     (DF_CC),HL
       RET
L0B03  BIT    1,(IY+1)
       JP     NZ,#0B1D
       LD     BC,(S_POSN)
       LD     HL,(DF_CC)
       RET
L0B24  CP     #80
       JR     C,L0B65
       CP     #90
       JR     NC,L0B52
       LD     B,A
       CALL   L0B38
       CALL   L0B03
       LD     DE,#5C92
       JP     PR_ALL
L0B38  LD     HL,#5C92
       CALL   L0B3E
L0B3E  RR     B
       SBC    A,A
       AND    #1C
       LD     C,A
       RR     B
       SBC    A,A
       AND    #E0
       OR     C
       LD     C,#04
L0B4C  LD     (HL),A
       INC    HL
       DEC    C
       JR     NZ,L0B4C
       RET
L0B52  SUB    #A5
       JR     NC,PO_TOK
       ADD    A,#15
       PUSH   BC
       LD     BC,(#5C7B)
       JR     L0B6A
PO_TOK CALL   #0C10
       JR     L0B03
L0B65  PUSH   BC
       LD     BC,CHARS-256
L0B6A  EX     DE,HL
       LD     HL,#5C3B
       RES    0,(HL)
       CP     #20
       JR     NZ,L0B76
       SET    0,(HL)
L0B76  LD     H,#00
       LD     L,A
       ADD    HL,HL
       ADD    HL,HL
       ADD    HL,HL
       ADD    HL,BC
       POP    BC
       EX     DE,HL
PR_ALL LD     A,C
       DEC    A
       LD     A,43
       JR     NZ,PR1
       DEC    B
       LD     C,A
       BIT    1,(IY+1)
       JR     Z,PR1
       PUSH   DE
       CALL   #0ECD
       LD     C,43
       POP    DE
       LD     A,C
PR1    CP     C
       PUSH   DE
       CALL   Z,SCROLL
       POP    DE
       PUSH   BC
       PUSH   HL
       PUSH   HL
       LD     A,43
       SUB    C
       AND    #03
       LD     C,A
       LD     B,0
       LD     HL,TABLE
       ADD    HL,BC
       LD     C,(HL)
       ADD    HL,BC
       EX     (SP),HL
       LD     C,(IY+87)
       LD     A,#08
       BIT    1,(IY+1)
       RET    Z
       SET    1,(IY+48)
       SCF
       RET
TABLE  DEFB   P0-$
       DEFB   P14-$
       DEFB   P24-$
       DEFB   P3-$
P0     LD     B,#FC
P03    EX     AF,AF'
       LD     A,(DE)
       CALL   PRLINE
       EX     AF,AF'
       CALL   C,PR6
       INC    H
       INC    E
       DEC    A
       JR     NZ,P03
       JR     ATTR
P14    EX     AF,AF'
       LD     A,(DE)
       RLCA
       RLCA
       PUSH   AF
       LD     B,#03
       CALL   PRLINE
       INC    L
       POP    AF
       LD     B,#F0
       CALL   PRLINE
       DEC    L
       EX     AF,AF'
       CALL   C,PR6
       INC    H
       INC    E
       DEC    A
       JR     NZ,P14
       JR     ATTR
P24    EX     AF,AF'
       LD     A,(DE)
       RLCA
       RLCA
       RLCA
       RLCA
       PUSH   AF
       LD     B,#0F
       CALL   PRLINE
       INC    L
       POP    AF
       LD     B,#C0
       CALL   PRLINE
       DEC    L
       EX     AF,AF'
       CALL   C,PR6
       INC    H
       INC    E
       DEC    A
       JR     NZ,P24
       JR     ATTR
P3     LD     B,#3F
P34    EX     AF,AF'
       LD     A,(DE)
       RRCA
       RRCA
       CALL   PRLINE
       EX     AF,AF'
       CALL   C,PR6
       INC    H
       INC    E
       DEC    A
       JR     NZ,P34
ATTR   DEC    H
       CALL   NC,#0BDB
       POP    HL
       POP    BC
       LD     A,43
       SUB    C
       DEC    C
       AND    #03
       RET    Z
       INC    L
       CP     #03
       RET    Z
       BIT    1,(IY+1)
       RET    NZ
       PUSH   HL
       CALL   #0BDB
       POP    HL
       RET
PRLINE BIT    2,C
       JR     Z,INV0
       XOR    B
INV0   BIT    0,C
       JR     NZ,OVER1
       XOR    (HL)
OVER1  AND    B
       XOR    (HL)
       LD     (HL),A
       RET
PR6    EX     AF,AF'
       LD     A,#20
       ADD    A,L
       LD     L,A
       EX     AF,AF'
       DEC    H
       RET
SCROLL BIT    1,(IY+1)
       RET    NZ
       LD     A,(DF_SZ)
       CP     B
       JR     NZ,CL_SET
SCR2   DEC    (IY+82)
       JR     NZ,SCR3
       LD     A,#18
       SUB    B
       LD     (23692),A
       LD     A,(SCFLAG)
       AND    A
       JR     Z,SCR3
       LD     A,#FD
       CALL   #1601
       RES    5,(IY+2)
       LD     A,(DF_SZ)
       CP     (IY+49)
       JR     C,NO_MSG
       SET    5,(IY+2)
       XOR    A
       LD     DE,#0CF8
       CALL   #0C0A
NO_MSG LD     HL,#5C3B
       SET    3,(HL)
       RES    5,(HL)
       EXX
       CALL   #15DE
       EXX
       CP     #20
       JR     Z,SC_BRK
       CP     #E2
       JR     Z,SC_BRK
       OR     #20
       CP     #6E
SC_BRK JP     Z,#0D00
       LD     A,#02
       CALL   #1601
SCR3   CALL   #0DFE
       LD     A,(DF_SZ)
       INC    A
       LD     B,A
       LD     C,43
       DEC    A
       CALL   NZ,#0CDB
CL_SET LD     HL,#5B00
       BIT    1,(IY+1)
       JR     NZ,CL_S2
CL_S1  PUSH   BC
       CALL   #0E9B
       POP    BC
CL_S2  LD     A,43
       SUB    C
       LD     E,A
       ADD    A,A
       ADD    A,E
       RRA
       AND    A
       RRA
       OR     L
       LD     L,A
       JP     L0ADC

SUB200 LD     BC,#0000
       LD     HL,#5C3B
       SET    3,(HL)
       BIT    5,(HL)
       RET    Z
       LD     A,(23560)
       RES    5,(HL)
       CALL   K_TEST
       LD     C,A
       RET    C
       LD     C,#00
       RET

PAUSE  CALL   #1E99
       SET    3,(IY+1)
PAUSE1 HALT
       LD     A,B
       OR     C
       JR     Z,PAUSE2
       DEC    BC
       BIT    5,(IY+1)
       JR     Z,PAUSE1
PAUSE2 CALL   #2D2B
       LD     A,(23560)
       LD     BC,#0000
       LD     (IY-50),C
       BIT    5,(IY+1)
       RET    Z
       RES    5,(IY+1)
       CALL   K_TEST
       LD     C,#00
       RET    NC
       LD     (23560),A
       RET

; Input routine

GETKEY LD     A,(23697)
       LD     (TEMP_P),A
       RES    7,(IY+2)
       LD     HL,#5C3B
       SET    3,(HL)
       BIT    5,(HL)
       JR     Z,K_WAIT
K_FETC LD     A,(23560)
       RES    5,(IY+1)
       PUSH   AF
       LD     D,0
       LD     E,(IY-1)
       LD     HL,#00C8
       CALL   #03B5
       BIT    7,(IY+2)
       RES    7,(IY+2)
       JR     Z,RSTOR_P
       LD     A,#20
       CALL   OUTCHR
       LD     A,28
       CALL   OUTCHR
RSTOR_ LD     A,(TEMP_P)
       LD     (23697),A
       POP    AF
K_TEST LD     C,A
       LD     HL,K_TAB
       CALL   #16DC
       LD     A,(HL)
       RET    C
       LD     A,C
       CP     #20
       CCF
       RET    C
       CP     #06
       JR     NZ,NO_KEY
       LD     A,(23658)
       XOR    #08
       LD     (23658),A
NO_KEY CP     A
       RET
K_TAB  DEFB   #08,28
       DEFB   #09,29
       DEFB   #0A,30
       DEFB   #0B,31
       DEFB   #0C,#7F
       DEFB   #0D,#0D
       DEFB   #AC,"?"
       DEFB   #C3,"|"
       DEFB   #C5,"]"
       DEFB   #C6,"["
       DEFB   #C7,"?"
       DEFB   #C8,"?"
       DEFB   #C9,"?"
       DEFB   #CB,"}"
       DEFB   #CC,"{"
       DEFB   #CD,"\"
       DEFB   #E2,"~"
       DEFB   #00

; wait for key input, flashing cursor in #2       
       
K_WAIT LD     HL,23697
       LD     A,(HL)
       LD     (TEMP_P),A
       SET    2,(HL)
       SET    0,(HL)
K_CURS LD     A,13
       LD     (BL_CT),A
       LD     A,#20
       CALL   OUTCHR
       LD     A,28
       CALL   OUTCHR
       LD     A,(23612)
       XOR    #80
       LD     (23612),A
K_HALT HALT
       BIT    5,(IY+1)
       JP     NZ,K_FETCH
       LD     A,(BL_CT)
       DEC    A
       LD     (BL_CT),A
       JR     NZ,K_HALT
       JR     K_CURS
       
; Plot a string in the graphics coordinate system
; Called by GOSUB 650
; String to be plotted must be on the calculator stack       
       
PRTSTR LD     A,#07
       CP     (IY+68)
       JR     C,PLOTSTR
       LD     (23678),A       ; do not plot off the bottom of the screen!
PLOTST CALL   #2BF1           ; STK-FETCH
       CALL   #2AB6           ; STK-STORE to balance the stack
STR_LP LD     A,B
       OR     C
       RET    Z               ; finished with string (but see note at the end!)
       PUSH   BC
       PUSH   DE
       LD     A,(DE)          ; get next char
       LD     L,A
       LD     H,0
       ADD    HL,HL
       ADD    HL,HL
       ADD    HL,HL
       LD     DE,CHARS-256
       ADD    HL,DE           ; point to first byte in character set
       EX     DE,HL
       LD     BC,(23677)      ; COORDS
       LD     A,C
       ADD    A,6
       LD     (23677),A       ; advance by 6 pixels (NOTE: no overflow check)
       LD     A,#BF           ; our graphic screen has 191 lines not 175.
       SUB    B
       CALL   #22B0           ; get start address in display file
       INC    A
       LD     C,A             ; pixel position of upper left + 1
       LD     B,#FF           ; assume all '1' pixels in char should be set
       BIT    3,(IY+87)       ; this is the permanent 'INVERSE 1' flag
       JR     Z,PR_ROW
       INC    B               ; if set, pixels on screen should be cleared
       
; loop for each line       
       
PR_ROW PUSH   BC
       PUSH   DE
       LD     A,(DE)          ; get pixel mask from character
       LD     D,A
       LD     E,#00           ; DE now holds pixel mask in MSB
SH_LOO DEC    C               ; C initially holds horizontal pixel position
       JR     Z,DO_PR         ; within the byte
       SRL    D               ; shift pixel mask in DE rightwards C times
       RR     E
       JR     SH_LOOP
       
; We now have B set according to INVERSE status (0 for INVERSE 1; $FF for INVERSE 0)
; and DE holding the mask corresponding to the character's bit pattern for this line
; The bits in B (0 or 1) are now 'impressed' onto the location in the display file
; (2 bytes since the 6-bit character pattern may overlap)
       
DO_PR  LD     A,B             ; get INVERSE mask (0 means INVERSE 1)
       XOR    (HL)
       AND    D               ; set or clear bits according to character pattern
       XOR    (HL)
       LD     (HL),A
       INC    L               ; and do so for next location
       LD     A,B
       XOR    (HL)
       AND    E
       XOR    (HL)
       LD     (HL),A
       DEC    L               ; go back to original location
       INC    H               ; go down one line (=256 bytes further)
       LD     A,H
       AND    #07             ; but first test if we're on a row boundary
       JR     NZ,PG_NXT       ; (multiple of 8 lines)
       LD     A,L
       ADD    A,#20           ; if so, the next line is 32 bytes further
       LD     L,A
       JR     C,PG_NXT        ; carry set if we've reached a new third in DFILE
       LD     A,H
       SUB    #08             ; else, adjust H so we remain in the same third
       LD     H,A
PG_NXT POP    DE              ; restore character set pointer
       POP    BC              ; restore INVERSE flag and pixel position
       INC    E               ; next byte in character set
       LD     A,E
       AND    #07             ; loop for 8 lines
       JR     NZ,PR_ROW       ; NOTE: CHARS should be on an 8-byte boundary!
       POP    DE              ; restore string pointer
       POP    BC              ; and length
       INC    DE              ; get next character from string
       DEC    BC
       JR     STR_LP

; NOTE: This routine fails to set the attribute location. This isn't a problem
; in BASICODE-3 (which has no colour support) but it is in BASICODE-3C.
; The cure seems to be to call the PO-ATTR routine in the ROM at location $0BDB
; for each character. This will set the attribute byte according to the values
; of ATTR-T and MASK-T. However, since this routine is supposed to plot a
; string anywhere in the graphics coordinate system, chances are big that the
; string to be plotted will overlap two adjacent attribute rows.
; One question which needs to be solved: should we set only one attribute row
; (and which one?) or go for two rows? In both cases the result may not look
; quite as we want it to...
